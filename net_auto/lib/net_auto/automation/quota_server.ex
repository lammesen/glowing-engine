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
  def check_out(site, meta) when is_binary(site) and is_map(meta), do: check_out(@name, site, meta)

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
       reservations: %{}
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

        new_state =
          state
          |> put_in([:global, :active], global.active + 1)
          |> put_in([:sites, site], %{site_entry | active: site_entry.active + 1})
          |> put_in([:reservations, ref], %{site: site, meta: meta, owner: from_pid})

        {:reply, {:ok, ref}, new_state}
    end
  end

  def handle_call({:check_in, ref, _reason}, _from, state) do
    case Map.pop(state.reservations, ref) do
      {nil, _reservations} ->
        {:reply, :ok, state}

      {%{site: site}, reservations} ->
        site_entry = Map.fetch!(state.sites, site)
        global_active = max(state.global.active - 1, 0)
        site_active = max(site_entry.active - 1, 0)

        new_state = %{
          state
          | reservations: reservations,
            global: %{state.global | active: global_active},
            sites: Map.put(state.sites, site, %{site_entry | active: site_active})
        }

        {:reply, :ok, new_state}
    end
  end

  def handle_call(:debug_state, _from, state), do: {:reply, state, state}

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
end
