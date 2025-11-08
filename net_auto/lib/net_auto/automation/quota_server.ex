defmodule NetAuto.Automation.QuotaServer do
  @moduledoc """
  Tracks active automation runs and enforces concurrency quotas.

  Quotas are evaluated for both the global runner pool and for a given site key.
  If either quota is exhausted the `check_out/2` call returns an error and the
  caller should fail fast before starting a run.
  """

  use GenServer

  @name __MODULE__

  @type reservation :: reference()
  @type site_key :: String.t()
  @type server_name :: atom() | pid()

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Attempts to reserve capacity for the given `site`.
  """
  @spec check_out(site_key(), map()) :: {:ok, reservation()} | {:error, {:quota_exceeded, term()}}
  def check_out(site, meta \\ %{})

  def check_out(site, meta) when is_binary(site) and is_map(meta),
    do: check_out(@name, site, meta)

  @spec check_out(server_name(), site_key(), map()) ::
          {:ok, reservation()} | {:error, {:quota_exceeded, term()}}
  def check_out(server, site, meta) when is_binary(site) and is_map(meta) do
    GenServer.call(server, {:check_out, site, meta})
  end

  @doc """
  Releases a previously granted reservation.
  """
  @spec check_in(reservation()) :: :ok
  def check_in(ref), do: check_in(@name, ref)

  @spec check_in(server_name(), reservation()) :: :ok
  def check_in(server, ref), do: GenServer.call(server, {:check_in, ref, :normal})

  @doc """
  Returns internal counters for debugging and tests.
  """
  @spec debug_state() :: map()
  def debug_state, do: debug_state(@name)

  @spec debug_state(server_name()) :: map()
  def debug_state(server), do: GenServer.call(server, :debug_state)

  @impl true
  def init(opts) do
    settings = load_settings(opts)

    {:ok,
     %{
       settings: settings,
       global: %{active: 0, limit: settings.global_limit},
       sites: %{},
       reservations: %{},
       owner_counts: %{},
       owner_monitors: %{},
       monitor_index: %{}
     }}
  end

  @impl true
  def handle_call({:check_out, site, meta}, {from_pid, _}, state) do
    %{settings: settings, global: global} = state
    site_entry = Map.get(state.sites, site, new_site_entry(settings, site))

    cond do
      global.active >= global.limit ->
        {:reply, {:error, {:quota_exceeded, :global}}, state}

      site_entry.active >= site_entry.limit ->
        {:reply, {:error, {:quota_exceeded, {:site, site}}}, state}

      true ->
        ref = make_ref()

        state = ensure_monitor(state, from_pid)
        owner_count = Map.get(state.owner_counts, from_pid, 0)
        global_active = global.active + 1
        site_active = site_entry.active + 1

        new_state =
          state
          |> put_in([:global, :active], global_active)
          |> put_in([:sites, site], %{site_entry | active: site_active})
          |> put_in([:reservations, ref], %{site: site, meta: meta, owner: from_pid})
          |> put_in([:owner_counts, from_pid], owner_count + 1)

        emit_checked_out(
          site,
          global_active,
          state.global.limit,
          site_active,
          site_entry.limit,
          meta
        )

        {:reply, {:ok, ref}, new_state}
    end
  end

  def handle_call({:check_in, ref, reason}, _from, state) do
    {new_state, _status} = release_reservation(state, ref, reason)
    {:reply, :ok, new_state}
  end

  def handle_call(:debug_state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_info({:DOWN, mref, :process, pid, reason}, state) do
    {pid_from_index, monitor_index} = Map.pop(state.monitor_index, mref, nil)
    state = %{state | monitor_index: monitor_index}

    refs =
      state.reservations
      |> Enum.filter(fn {_ref, reservation} ->
        reservation.owner == pid_from_index || reservation.owner == pid
      end)
      |> Enum.map(&elem(&1, 0))

    new_state =
      refs
      |> Enum.reduce(state, fn ref, acc ->
        {next_state, _} = release_reservation(acc, ref, {:down, reason})
        next_state
      end)

    {:noreply, new_state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp load_settings(opts) do
    env_settings =
      Application.get_env(:net_auto, NetAuto.Automation, %{})
      |> Map.new()

    overrides =
      opts
      |> Enum.into(%{})
      |> Map.take([:global_limit, :site_limits, :default_site_limit])

    env_settings
    |> Map.put_new(:global_limit, 50)
    |> Map.put_new(:site_limits, %{})
    |> Map.put_new(:default_site_limit, 5)
    |> Map.merge(overrides, fn _key, _v1, v2 -> v2 end)
  end

  defp new_site_entry(settings, site) do
    limit =
      settings.site_limits
      |> Map.get(site, settings.default_site_limit)

    %{active: 0, limit: limit}
  end

  defp ensure_monitor(state, pid) do
    case Map.has_key?(state.owner_monitors, pid) do
      true ->
        state

      false ->
        ref = Process.monitor(pid)

        %{
          state
          | owner_monitors: Map.put(state.owner_monitors, pid, ref),
            monitor_index: Map.put(state.monitor_index, ref, pid)
        }
    end
  end

  defp release_reservation(state, ref, reason) do
    case Map.pop(state.reservations, ref) do
      {nil, _} ->
        {state, :noop}

      {%{site: site, owner: owner, meta: meta}, reservations} ->
        site_entry = Map.fetch!(state.sites, site)
        global_active = max(state.global.active - 1, 0)
        site_active = max(site_entry.active - 1, 0)

        state =
          %{state | reservations: reservations}
          |> put_in([:global, :active], global_active)
          |> put_in([:sites, site], %{site_entry | active: site_active})

        {state, owner_removed?} = decrement_owner(state, owner)

        emit_checked_in(
          site,
          global_active,
          state.global.limit,
          site_active,
          site_entry.limit,
          reason,
          meta
        )

        {state, owner_removed?}
    end
  end

  defp decrement_owner(state, owner) do
    count = Map.get(state.owner_counts, owner, 0) - 1

    cond do
      count > 0 ->
        {%{state | owner_counts: Map.put(state.owner_counts, owner, count)}, :ok}

      true ->
        owner_counts = Map.delete(state.owner_counts, owner)
        {monitor_ref, owner_monitors} = Map.pop(state.owner_monitors, owner, nil)

        monitor_index =
          case monitor_ref do
            nil ->
              state.monitor_index

            ref ->
              Process.demonitor(ref, [:flush])
              Map.delete(state.monitor_index, ref)
          end

        {%{
           state
           | owner_counts: owner_counts,
             owner_monitors: owner_monitors,
             monitor_index: monitor_index
         }, :removed}
    end
  end

  defp emit_checked_out(site, global_active, global_limit, site_active, site_limit, meta) do
    measurements = %{global_active: global_active, site_active: site_active}

    metadata = %{
      site: site,
      global_limit: global_limit,
      site_limit: site_limit,
      meta: meta
    }

    :telemetry.execute([:net_auto, :quota, :checked_out], measurements, metadata)
  end

  defp emit_checked_in(site, global_active, global_limit, site_active, site_limit, reason, meta) do
    measurements = %{global_active: global_active, site_active: site_active}

    metadata = %{
      site: site,
      global_limit: global_limit,
      site_limit: site_limit,
      reason: reason,
      meta: meta
    }

    :telemetry.execute([:net_auto, :quota, :checked_in], measurements, metadata)
  end
end
