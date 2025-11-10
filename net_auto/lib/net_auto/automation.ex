defmodule NetAuto.Automation do
  @moduledoc """
  Data API for automation runs and streamed output chunks.
  """

  import Ecto.Query, warn: false
  alias Ecto.UUID
  alias NetAuto.Repo
  alias Oban

  alias NetAuto.Automation.{BulkJob, QuotaServer, Run, RunChunk, RunServer}
  alias NetAuto.Inventory.Device

  @retention_defaults %{max_age_days: 30, max_total_bytes: :infinity}
  @history_default_limit 25
  @history_max_limit 100
  @default_site "default"
  @bulk_chunk_size 50

  def list_runs(opts \\ []) do
    Run |> maybe_preload(opts) |> Repo.all()
  end

  def get_run!(id, opts \\ []) do
    Run |> maybe_preload(opts) |> Repo.get!(id)
  end

  def create_run(attrs \\ %{}) do
    %Run{}
    |> Run.changeset(attrs)
    |> Repo.insert()
    |> maybe_emit_run_created()
  end

  def update_run(%Run{} = run, attrs) do
    run
    |> Run.changeset(attrs)
    |> Repo.update()
  end

  def delete_run(%Run{} = run), do: Repo.delete(run)

  def change_run(%Run{} = run, attrs \\ %{}) do
    Run.changeset(run, attrs)
  end

  @doc """
  Returns the effective retention configuration merged with defaults.
  """
  def retention_config do
    configured = Application.get_env(:net_auto, __MODULE__.Retention, %{})

    defaults()
    |> Map.merge(configured)
    |> normalize_retention_config()
  end

  def execute_run(%Device{} = device, attrs, opts \\ []) when is_map(attrs) do
    runtime = runtime_options(opts)

    case create_run(build_run_attrs(device, attrs)) do
      {:ok, run} ->
        site = site_key(device)

        case checkout_quota(runtime.quota_server, site, run, device) do
          {:ok, reservation} ->
            start_run_server(
              runtime.run_supervisor,
              run,
              device,
              attrs,
              site,
              reservation,
              runtime.quota_server
            )

          {:error, reason} ->
            mark_run_error(run, format_quota_reason(reason))
            {:error, reason}
        end

      error ->
        error
    end
  end

  def cancel_run(run_id) when is_integer(run_id) do
    RunServer.cancel(run_id)
  end

  def bulk_enqueue(command, device_ids, opts \\ []) do
    with {:ok, normalized_command} <- normalize_bulk_command(command),
         {:ok, ids} <- normalize_device_ids(device_ids) do
      chunk_size =
        opts
        |> Keyword.get(:chunk_size, @bulk_chunk_size)
        |> normalize_chunk_size()

      bulk_ref = Keyword.get(opts, :bulk_ref, UUID.generate())
      requested_by = Keyword.get(opts, :requested_by)

      jobs =
        ids
        |> Enum.chunk_every(chunk_size)
        |> Enum.map(fn chunk_ids ->
          %{
            "command" => normalized_command,
            "device_ids" => chunk_ids,
            "bulk_ref" => bulk_ref
          }
          |> maybe_put_requested_by(requested_by)
          |> BulkJob.new()
        end)

      insert_bulk_jobs(jobs, bulk_ref)
    end
  end

  def paginated_runs_for_device(device_id, params \\ %{}) do
    filters = normalize_history_params(params)
    page = max(filters.page, 1)
    per_page = filters.per_page
    offset = per_page * (page - 1)

    base_query =
      Run
      |> where([r], r.device_id == ^device_id)
      |> join(:inner, [r], d in assoc(r, :device))
      |> maybe_filter_statuses(filters.statuses)
      |> maybe_filter_requested_by(filters.requested_by)
      |> maybe_filter_query(filters.query)
      |> maybe_filter_date_range(filters.from, filters.to)

    total = Repo.aggregate(base_query, :count, :id)

    entries =
      base_query
      |> order_by([r, _d], desc: fragment("coalesce(?, ?)", r.requested_at, r.inserted_at))
      |> limit(^per_page)
      |> offset(^offset)
      |> preload([_r, d], device: d)
      |> Repo.all()

    %{entries: entries, total: total, page: page, per_page: per_page}
  end

  def latest_run_for_device(device_id) do
    Run
    |> where([r], r.device_id == ^device_id)
    |> order_by([r], desc: fragment("coalesce(?, ?)", r.requested_at, r.inserted_at))
    |> limit(1)
    |> Repo.one()
  end

  # Run chunks --------------------------------------------------------------

  def list_run_chunks(run_id) do
    RunChunk
    |> where(run_id: ^run_id)
    |> order_by([c], asc: c.seq)
    |> Repo.all()
  end

  def append_chunk(attrs \\ %{}) do
    %RunChunk{}
    |> RunChunk.changeset(attrs)
    |> Repo.insert()
    |> maybe_emit_chunk_appended()
  end

  def change_run_chunk(%RunChunk{} = chunk, attrs \\ %{}) do
    RunChunk.changeset(chunk, attrs)
  end

  defp maybe_preload(queryable, opts) do
    case Keyword.get(opts, :preload) do
      nil -> queryable
      preload -> preload(queryable, ^preload)
    end
  end

  defp normalize_history_params(params) do
    params = Map.new(params, fn {k, v} -> {normalize_history_key(k), v} end)

    %{
      page: parse_positive_int(Map.get(params, :page), 1),
      per_page: normalize_per_page(Map.get(params, :per_page)),
      statuses: normalize_statuses(Map.get(params, :statuses, [])),
      requested_by: params |> Map.get(:requested_by) |> blank_to_nil() |> maybe_downcase(),
      query: params |> Map.get(:query) |> blank_to_nil(),
      from: params |> Map.get(:from) |> parse_datetime(),
      to: params |> Map.get(:to) |> parse_datetime()
    }
  end

  defp normalize_history_key(key) when is_atom(key), do: key
  defp normalize_history_key("page"), do: :page
  defp normalize_history_key("per_page"), do: :per_page
  defp normalize_history_key("statuses"), do: :statuses
  defp normalize_history_key("requested_by"), do: :requested_by
  defp normalize_history_key("query"), do: :query
  defp normalize_history_key("from"), do: :from
  defp normalize_history_key("to"), do: :to
  defp normalize_history_key(other), do: other

  defp parse_positive_int(value, _default) when is_integer(value) and value > 0, do: value

  defp parse_positive_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} when int > 0 -> int
      _ -> default
    end
  end

  defp parse_positive_int(_value, default), do: default

  defp normalize_per_page(nil), do: @history_default_limit

  defp normalize_per_page(value) do
    value
    |> parse_positive_int(@history_default_limit)
    |> min(@history_max_limit)
  end

  defp normalize_statuses(value) when is_list(value) do
    valid = MapSet.new(Ecto.Enum.values(Run, :status))

    value
    |> Enum.map(&normalize_status/1)
    |> Enum.filter(&(&1 && MapSet.member?(valid, &1)))
    |> Enum.uniq()
  end

  defp normalize_statuses(_), do: []

  defp normalize_status(value) when is_atom(value), do: value

  defp normalize_status(value) when is_binary(value) do
    trimmed = value |> String.trim() |> String.downcase()

    if trimmed == "" do
      nil
    else
      try do
        String.to_existing_atom(trimmed)
      rescue
        ArgumentError -> nil
      end
    end
  end

  defp normalize_status(_), do: nil

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp maybe_downcase(nil), do: nil
  defp maybe_downcase(value) when is_binary(value), do: String.downcase(value)
  defp maybe_downcase(value), do: value

  defp parse_datetime(%DateTime{} = dt), do: DateTime.truncate(dt, :second)

  defp parse_datetime(%NaiveDateTime{} = dt) do
    dt
    |> NaiveDateTime.truncate(:second)
    |> DateTime.from_naive!("Etc/UTC")
  end

  defp parse_datetime(value) when is_binary(value) do
    trimmed = String.trim(value)

    case DateTime.from_iso8601(trimmed) do
      {:ok, dt, _offset} -> DateTime.truncate(dt, :second)
      {:error, _} -> nil
    end
  end

  defp parse_datetime(_value), do: nil

  defp maybe_filter_statuses(query, []), do: query

  defp maybe_filter_statuses(query, statuses) do
    where(query, [r, _d], r.status in ^statuses)
  end

  defp maybe_filter_requested_by(query, nil), do: query

  defp maybe_filter_requested_by(query, requested_by) do
    where(query, [r, _d], fragment("lower(?) = ?", r.requested_by, ^requested_by))
  end

  defp maybe_filter_query(query, nil), do: query

  defp maybe_filter_query(query, query_string) do
    trimmed = String.trim(query_string)

    if trimmed == "" do
      query
    else
      pattern = "%#{trimmed}%"

      where(
        query,
        [r, d],
        ilike(r.command, ^pattern) or
          ilike(d.hostname, ^pattern) or
          ilike(d.site, ^pattern)
      )
    end
  end

  defp maybe_filter_date_range(query, nil, nil), do: query

  defp maybe_filter_date_range(query, from, to) do
    cond do
      from && to ->
        where(
          query,
          [r, _d],
          fragment("coalesce(?, ?) >= ?", r.requested_at, r.inserted_at, ^from) and
            fragment("coalesce(?, ?) <= ?", r.requested_at, r.inserted_at, ^to)
        )

      from ->
        where(
          query,
          [r, _d],
          fragment("coalesce(?, ?) >= ?", r.requested_at, r.inserted_at, ^from)
        )

      to ->
        where(query, [r, _d], fragment("coalesce(?, ?) <= ?", r.requested_at, r.inserted_at, ^to))
    end
  end

  defp build_run_attrs(device, attrs) do
    command =
      attrs
      |> Map.get(:command, "")
      |> to_string()
      |> String.trim()

    requested_at =
      attrs
      |> Map.get(:requested_at)
      |> case do
        %DateTime{} = dt -> dt
        _ -> DateTime.utc_now() |> DateTime.truncate(:second)
      end

    %{
      command: command,
      status: :pending,
      device_id: device.id,
      requested_by: Map.get(attrs, :requested_by),
      requested_at: requested_at,
      requested_for: Map.get(attrs, :requested_for),
      command_template_id: Map.get(attrs, :command_template_id)
    }
  end

  defp runtime_options(opts) do
    config = Application.get_env(:net_auto, __MODULE__, [])

    %{
      quota_server:
        Keyword.get(opts, :quota_server, Keyword.get(config, :quota_server, QuotaServer)),
      run_supervisor:
        Keyword.get(
          opts,
          :run_supervisor,
          Keyword.get(config, :run_supervisor, NetAuto.Automation.RunSupervisor)
        )
    }
  end

  defp checkout_quota(quota_server, site, run, device) do
    meta = %{run_id: run.id, device_id: device.id}
    QuotaServer.check_out(quota_server, site, meta)
  end

  defp start_run_server(run_supervisor, run, device, attrs, site, reservation, quota_server) do
    adapter = protocols_adapter()
    adapter_opts = Map.get(attrs, :adapter_opts, %{})

    run_server_opts = [
      run: run,
      device: device,
      adapter: adapter,
      command: run.command,
      site: site,
      reservation: reservation,
      quota_server: quota_server,
      adapter_opts: adapter_opts
    ]

    case DynamicSupervisor.start_child(run_supervisor, {RunServer, run_server_opts}) do
      {:ok, _pid} ->
        {:ok, run}

      {:error, reason} = error ->
        QuotaServer.check_in(quota_server, reservation)
        mark_run_error(run, format_error(reason))
        error
    end
  end

  defp mark_run_error(run, reason) do
    update_run(run, %{status: :error, error_reason: reason, finished_at: DateTime.utc_now()})
  end

  defp site_key(%Device{site: site}) when is_binary(site) and site != "", do: site
  defp site_key(_), do: @default_site

  defp protocols_adapter do
    Application.get_env(:net_auto, NetAuto.Protocols, adapter: NetAuto.Protocols.SSHAdapter)
    |> Keyword.fetch!(:adapter)
  end

  defp maybe_emit_run_created({:ok, run} = result) do
    :telemetry.execute([:net_auto, :run, :created], %{count: 1}, run_created_metadata(run))
    result
  end

  defp maybe_emit_run_created(result), do: result

  defp run_created_metadata(run) do
    %{
      run_id: run.id,
      device_id: run.device_id,
      requested_by: run.requested_by,
      site: associated_device_field(run, :site),
      protocol: associated_device_field(run, :protocol),
      status: run.status
    }
  end

  defp associated_device_field(run, field) do
    case Map.get(run, :device) do
      %Device{} = device -> Map.get(device, field)
      _ -> nil
    end
  end

  defp maybe_emit_chunk_appended({:ok, chunk} = result) do
    measurements = %{count: 1, bytes: chunk_data_size(chunk)}
    metadata = %{run_id: chunk.run_id, seq: chunk.seq}
    :telemetry.execute([:net_auto, :run, :chunk_appended], measurements, metadata)
    result
  end

  defp maybe_emit_chunk_appended(result), do: result

  defp chunk_data_size(%RunChunk{data: data}) when is_binary(data), do: byte_size(data)
  defp chunk_data_size(_), do: 0

  defp insert_bulk_jobs([], _bulk_ref), do: {:error, :no_devices}

  defp insert_bulk_jobs(jobs, bulk_ref) do
    case Oban.insert_all(jobs) do
      inserted when is_list(inserted) -> {:ok, %{bulk_ref: bulk_ref, jobs: inserted}}
      %Ecto.Multi{} = multi -> {:ok, %{bulk_ref: bulk_ref, jobs: multi}}
    end
  rescue
    exception -> {:error, exception}
  end

  defp maybe_put_requested_by(args, nil), do: args
  defp maybe_put_requested_by(args, requested_by), do: Map.put(args, "requested_by", requested_by)

  defp defaults, do: @retention_defaults

  defp normalize_retention_config(config) do
    %{
      max_age_days:
        config
        |> Map.get(:max_age_days, defaults().max_age_days)
        |> normalize_positive_integer(defaults().max_age_days),
      max_total_bytes:
        config
        |> Map.get(:max_total_bytes, defaults().max_total_bytes)
        |> normalize_max_total_bytes()
    }
  end

  defp normalize_positive_integer(value, _default)
       when is_integer(value) and value > 0,
       do: value

  defp normalize_positive_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} when int > 0 -> int
      _ -> default
    end
  end

  defp normalize_positive_integer(_value, default), do: default

  defp normalize_max_total_bytes(value) when value in [nil, :infinity], do: :infinity

  defp normalize_max_total_bytes(value) when is_integer(value) and value > 0, do: value

  defp normalize_max_total_bytes(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} when int > 0 -> int
      _ -> defaults().max_total_bytes
    end
  end

  defp normalize_max_total_bytes(_value), do: defaults().max_total_bytes

  defp normalize_bulk_command(command) when is_binary(command) do
    trimmed = command |> String.trim()

    if trimmed == "" do
      {:error, :invalid_command}
    else
      {:ok, trimmed}
    end
  end

  defp normalize_bulk_command(_), do: {:error, :invalid_command}

  defp normalize_device_ids(ids) when is_list(ids) do
    normalized =
      ids
      |> Enum.map(&normalize_device_id/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    if normalized == [] do
      {:error, :no_devices}
    else
      {:ok, normalized}
    end
  end

  defp normalize_device_ids(_), do: {:error, :invalid_devices}

  defp normalize_device_id(%Device{id: id}), do: normalize_device_id(id)

  defp normalize_device_id(id) when is_integer(id) and id > 0, do: id

  defp normalize_device_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _} when int > 0 -> int
      _ -> nil
    end
  end

  defp normalize_device_id(_), do: nil

  defp normalize_chunk_size(value) when is_integer(value) and value > 0, do: value
  defp normalize_chunk_size(_), do: @bulk_chunk_size

  defp format_quota_reason({:quota_exceeded, :global}), do: "quota_exceeded:global"
  defp format_quota_reason({:quota_exceeded, {:site, site}}), do: "quota_exceeded:#{site}"
  defp format_quota_reason(reason), do: inspect(reason)

  defp format_error({:error, reason}), do: format_error(reason)
  defp format_error({:shutdown, reason}), do: format_error(reason)
  defp format_error(%{__struct__: _} = reason), do: inspect(reason)
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_error(reason), do: inspect(reason)
end
