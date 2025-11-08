defmodule NetAutoWeb.RunLive do
  @moduledoc """
  Device run workspace. Later tasks add streaming adapters; this step wires run
  history, filtering, and local command execution.
  """

  use NetAutoWeb, :live_view

  alias Phoenix.PubSub
  alias NetAuto.Accounts
  alias NetAuto.Automation
  alias NetAuto.Inventory
  alias NetAuto.Network

  @status_options [:pending, :running, :ok, :error]
  @history_per_page 20
  @bulk_topic_prefix "bulk:"

  @impl true
  def mount(%{"device_id" => device_id_param}, session, socket) do
    device_id = parse_device_id(device_id_param)
    start_time = System.monotonic_time()

    result = initialize_socket(device_id, session, socket)
    emit_liveview_mount(device_id, start_time)
    result
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign_bulk_context(socket, Map.get(params, "bulk_ref"))}
  end

  @impl true
  def handle_event("filter_history", params, socket) do
    filters = filters_from_params(params, socket.assigns.history_filters)
    history = fetch_history(socket.assigns.device.id, filters)
    selected_run = maybe_select_existing_run(socket.assigns.selected_run, history.entries)

    socket =
      socket
      |> assign(:history_filters, filters)
      |> assign(:history, history)
      |> put_selected_run(selected_run)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_run", %{"run-id" => run_id}, socket) do
    run = Automation.get_run!(String.to_integer(run_id))
    {:noreply, put_selected_run(socket, run)}
  end

  @impl true
  def handle_event("run_command", %{"command" => command_param}, socket) do
    command = command_param |> to_string() |> String.trim()

    if command == "" do
      {:noreply, put_flash(socket, :error, "Command is required")}
    else
      attrs = %{requested_by: current_user_email(socket)}
      emit_command_submitted(command, socket.assigns.device.id, attrs.requested_by)

      case Network.execute_command(socket.assigns.device.id, command, attrs) do
        {:ok, _run} ->
          history = fetch_history(socket.assigns.device.id, socket.assigns.history_filters)

          {:noreply,
           socket
           |> assign(:history, history)
           |> put_flash(:info, "Run started")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Unable to start run: #{format_reason(reason)}")}
      end
    end
  end

  @impl true
  def handle_event("set_tab", %{"tab" => tab_param}, socket) do
    {:noreply, assign(socket, :tab, normalize_tab(tab_param))}
  end

  @impl true
  def handle_info({:subscribe_run, run_id}, socket) do
    {:noreply, subscribe_to_run(socket, run_id)}
  end

  def handle_info({:chunk, run_id, seq, data}, %{assigns: %{selected_run_id: run_id}} = socket) do
    chunk = %{id: seq, seq: seq, data: data}
    {:noreply, stream_insert(socket, :chunks, chunk, at: -1)}
  end

  def handle_info({:chunk, _run_id, _seq, _data}, socket), do: {:noreply, socket}

  def handle_info({:run_finished, run}, socket) do
    socket =
      socket
      |> assign(:history, fetch_history(socket.assigns.device.id, socket.assigns.history_filters))
      |> maybe_update_selected_run(run)

    {:noreply, socket}
  end

  def handle_info({:bulk_progress, %{bulk_ref: ref} = payload}, socket) do
    {:noreply, maybe_update_bulk_progress(socket, ref, payload)}
  end

  def handle_info({:bulk_summary, %{bulk_ref: ref} = payload}, socket) do
    {:noreply, maybe_update_bulk_summary(socket, ref, payload)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />
    <section class="mx-auto flex max-w-6xl flex-col gap-6 px-6 py-10">
      <header>
        <p class="text-sm text-base-content/70">Device run workspace</p>
        <h1 class="text-3xl font-semibold text-base-content">{@device.hostname}</h1>
        <p class="text-base text-base-content/80">
          Run workspace coming soon. This page will stream command output and show history for {@device.hostname}.
        </p>
      </header>

      <div class="grid gap-6 lg:grid-cols-[320px_1fr]">
        <aside class="space-y-4 rounded-xl border border-base-200 bg-base-100 p-5">
          <h2 class="text-lg font-semibold">Run history</h2>
          <form id="history-filter-form" class="space-y-3" phx-submit="filter_history">
            <label class="block text-sm font-medium">
              Statuses
              <select
                name="statuses[]"
                multiple
                class="select select-bordered mt-1 w-full"
                size="4"
              >
                <option
                  :for={status <- @status_options}
                  value={status}
                  selected={status in @history_filters.statuses}
                >
                  {String.upcase(to_string(status))}
                </option>
              </select>
            </label>

            <label class="block text-sm font-medium">
              Operator
              <input
                type="text"
                name="requested_by"
                value={@history_filters.requested_by || ""}
                class="input input-bordered mt-1 w-full"
                placeholder="email or name"
              />
            </label>

            <label class="block text-sm font-medium">
              Search
              <input
                type="text"
                name="query"
                value={@history_filters.query || ""}
                class="input input-bordered mt-1 w-full"
                placeholder="command, hostname, site"
              />
            </label>

            <div class="grid grid-cols-2 gap-3">
              <label class="text-sm font-medium">
                From
                <input
                  type="datetime-local"
                  name="from"
                  value={datetime_input_value(@history_filters.from)}
                  class="input input-bordered mt-1 w-full"
                />
              </label>
              <label class="text-sm font-medium">
                To
                <input
                  type="datetime-local"
                  name="to"
                  value={datetime_input_value(@history_filters.to)}
                  class="input input-bordered mt-1 w-full"
                />
              </label>
            </div>

            <button type="submit" class="btn btn-primary w-full">Apply filters</button>
          </form>

          <p class="text-sm text-base-content/60">Total runs: {@history.total}</p>

          <ul id="run-history-list" class="space-y-2">
            <li :for={run <- @history.entries} id={"run-entry-#{run.id}"}>
              <button
                type="button"
                phx-click="select_run"
                phx-value-run-id={run.id}
                class={history_item_classes(run.id == @selected_run_id)}
              >
                <div class="flex items-center justify-between text-sm font-medium">
                  <span class="font-mono text-xs text-base-content/70">#{run.id}</span>
                  <span class="badge badge-sm">{String.upcase(to_string(run.status))}</span>
                </div>
                <p class="mt-1 truncate text-left font-mono text-sm">{run.command}</p>
                <p class="text-left text-xs text-base-content/60">
                  {run.requested_by || "unknown"} • {format_timestamp(
                    run.requested_at || run.inserted_at
                  )}
                </p>
              </button>
            </li>
            <li :if={Enum.empty?(@history.entries)} class="text-sm text-base-content/60">
              No runs match the selected filters.
            </li>
          </ul>
        </aside>

        <div class="space-y-4 rounded-xl border border-base-200 bg-base-100 p-6">
          <section
            :if={@bulk_context}
            id="bulk-context-panel"
            class="rounded-lg border border-base-200 bg-base-300/30 p-4"
          >
            <p class="text-sm font-semibold uppercase text-base-content/70">
              Bulk job {@bulk_context.ref}
            </p>
            <p :if={@bulk_context.latest_progress} class="text-sm text-base-content">
              Last status: {format_bulk_status(@bulk_context.latest_progress)}
            </p>
            <p :if={!@bulk_context.latest_progress} class="text-sm text-base-content/60">
              Waiting for progress updates...
            </p>
            <p :if={@bulk_context.summary} class="mt-1 text-xs text-base-content/70">
              Summary: ok={@bulk_context.summary.ok} error={@bulk_context.summary.error}
            </p>
          </section>

          <.command_form />

          <div class="tabs tabs-boxed w-fit">
            <button
              type="button"
              phx-click="set_tab"
              phx-value-tab="live_output"
              class={tab_button_classes(@tab == :live_output)}
            >
              Live Output
            </button>
            <button
              type="button"
              phx-click="set_tab"
              phx-value-tab="details"
              class={tab_button_classes(@tab == :details)}
            >
              Run Details
            </button>
          </div>

          <div
            :if={@tab == :live_output}
            class="max-h-96 overflow-y-auto rounded-lg border border-base-200 bg-base-300/20 p-4"
          >
            <p :if={!@selected_run} class="text-sm text-base-content/60">
              Select a run to view output.
            </p>
            <div
              :if={@selected_run}
              id="run-output-stream"
              phx-update="stream"
              class="space-y-3 font-mono text-sm text-base-content"
            >
              <pre
                :for={{dom_id, chunk} <- @streams.chunks}
                id={dom_id}
                class="whitespace-pre-wrap break-words"
              >{chunk.data}</pre>
            </div>
          </div>

          <div :if={@tab == :details} class="space-y-3">
            <p :if={!@selected_run} class="text-sm text-base-content/60">
              Select a run to view metadata.
            </p>
            <dl :if={@selected_run} class="grid grid-cols-1 gap-3 text-sm text-base-content">
              <div>
                <dt class="font-semibold">Run status</dt>
                <dd>{String.upcase(to_string(@selected_run.status))}</dd>
              </div>
              <div>
                <dt class="font-semibold">Operator</dt>
                <dd>{@selected_run.requested_by || "unknown"}</dd>
              </div>
              <div>
                <dt class="font-semibold">Requested at</dt>
                <dd>{format_timestamp(@selected_run.requested_at || @selected_run.inserted_at)}</dd>
              </div>
              <div>
                <dt class="font-semibold">Exit code</dt>
                <dd>{@selected_run.exit_code || "pending"}</dd>
              </div>
              <div>
                <dt class="font-semibold">Bytes</dt>
                <dd>{@selected_run.bytes || 0}</dd>
              </div>
            </dl>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :rest, :global

  defp command_form(assigns) do
    ~H"""
    <form id="run-command-form" phx-submit="run_command" class="space-y-2">
      <label class="text-sm font-medium text-base-content">Command</label>
      <textarea
        name="command"
        class="textarea textarea-bordered h-28 w-full font-mono"
        placeholder="show version"
        required
      ></textarea>
      <button type="submit" class="btn btn-primary">Run command</button>
    </form>
    """
  end

  defp emit_liveview_mount(device_id, start_time) do
    duration_ms =
      start_time
      |> then(&(System.monotonic_time() - &1))
      |> System.convert_time_unit(:native, :millisecond)

    :telemetry.execute(
      [:net_auto, :liveview, :mount],
      %{duration_ms: duration_ms, count: 1},
      %{view: __MODULE__, device_id: device_id}
    )
  end

  defp emit_command_submitted(command, device_id, requested_by) do
    :telemetry.execute(
      [:net_auto, :liveview, :command_submitted],
      %{count: 1},
      %{view: __MODULE__, device_id: device_id, requested_by: requested_by, command: command}
    )
  end

  defp initialize_socket(device_id, session, socket) do
    device = Inventory.get_device!(device_id)

    filters = default_filters()
    history = fetch_history(device.id, filters)
    selected_run = Automation.latest_run_for_device(device.id) || List.first(history.entries)

    socket =
      socket
      |> assign(:current_user, fetch_current_user(session))
      |> assign(:page_title, "#{device.hostname} • Runs")
      |> assign(:device, device)
      |> assign(:history, history)
      |> assign(:history_filters, filters)
      |> assign(:status_options, @status_options)
      |> assign(:tab, :live_output)
      |> assign(:subscribed_run_id, nil)
      |> assign(:selected_run, selected_run)
      |> assign(:selected_run_id, selected_run && selected_run.id)
      |> assign(:bulk_context, nil)
      |> assign(:bulk_context_topic, nil)
      |> stream(:chunks, chunks_for(selected_run))

    if selected_run do
      Process.send_after(self(), {:subscribe_run, selected_run.id}, 0)
    end

    {:ok, socket}
  end

  defp history_item_classes(true), do: "btn btn-soft btn-primary w-full text-left"
  defp history_item_classes(false), do: "btn btn-ghost w-full text-left"

  defp tab_button_classes(true), do: "tab tab-active"
  defp tab_button_classes(false), do: "tab"

  defp normalize_tab("details"), do: :details
  defp normalize_tab(_), do: :live_output

  defp parse_device_id(device_id) when is_integer(device_id), do: device_id

  defp parse_device_id(device_id) when is_binary(device_id) do
    case Integer.parse(device_id) do
      {int, _} -> int
      :error -> raise ArgumentError, "invalid device id"
    end
  end

  defp default_filters do
    %{
      page: 1,
      per_page: @history_per_page,
      statuses: [],
      requested_by: nil,
      query: nil,
      from: nil,
      to: nil
    }
  end

  defp filters_from_params(params, existing_filters) do
    %{
      page: 1,
      per_page: existing_filters.per_page,
      statuses: parse_statuses(Map.get(params, "statuses", [])),
      requested_by: blank_to_nil(Map.get(params, "requested_by")),
      query: blank_to_nil(Map.get(params, "query")),
      from: parse_datetime_local(Map.get(params, "from")),
      to: parse_datetime_local(Map.get(params, "to"))
    }
  end

  defp parse_statuses(values) do
    values
    |> List.wrap()
    |> Enum.map(&status_from_param/1)
    |> Enum.filter(& &1)
  end

  defp status_from_param(value) when is_atom(value) and value in @status_options, do: value

  defp status_from_param(value) when is_binary(value) do
    normalized = value |> String.trim() |> String.downcase()

    Enum.find(@status_options, fn status -> Atom.to_string(status) == normalized end)
  end

  defp status_from_param(_), do: nil

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp parse_datetime_local(nil), do: nil
  defp parse_datetime_local(""), do: nil

  defp parse_datetime_local(value) do
    value
    |> pad_datetime_seconds()
    |> NaiveDateTime.from_iso8601()
    |> case do
      {:ok, naive} -> DateTime.from_naive!(naive, "Etc/UTC")
      _ -> nil
    end
  end

  defp pad_datetime_seconds(value) do
    case String.length(value) do
      16 -> value <> ":00"
      _ -> value
    end
  end

  defp datetime_input_value(nil), do: ""

  defp datetime_input_value(%DateTime{} = dt) do
    dt
    |> DateTime.shift_zone!("Etc/UTC")
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%dT%H:%M:%S")
  end

  defp format_timestamp(nil), do: "n/a"

  defp format_timestamp(%DateTime{} = dt) do
    dt
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")
  end

  defp fetch_history(device_id, filters) do
    params =
      %{
        "page" => Integer.to_string(filters.page),
        "per_page" => Integer.to_string(filters.per_page),
        "statuses" => Enum.map(filters.statuses, &Atom.to_string/1),
        "requested_by" => filters.requested_by,
        "query" => filters.query,
        "from" => encode_datetime(filters.from),
        "to" => encode_datetime(filters.to)
      }
      |> Enum.reject(fn {_k, v} -> v in [nil, "", []] end)
      |> Map.new()

    Automation.paginated_runs_for_device(device_id, params)
  end

  defp encode_datetime(nil), do: nil
  defp encode_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp maybe_select_existing_run(nil, entries), do: List.first(entries)

  defp maybe_select_existing_run(%{id: id} = current, entries) do
    if Enum.any?(entries, &(&1.id == id)) do
      current
    else
      List.first(entries)
    end
  end

  defp put_selected_run(socket, run) do
    socket
    |> assign(:selected_run, run)
    |> assign(:selected_run_id, run && run.id)
    |> stream(:chunks, chunks_for(run), reset: true)
    |> subscribe_to_run(run && run.id)
  end

  defp chunks_for(nil), do: []
  defp chunks_for(run), do: Automation.list_run_chunks(run.id)

  defp subscribe_to_run(socket, nil), do: maybe_unsubscribe(socket)

  defp subscribe_to_run(socket, run_id) do
    cond do
      socket.assigns.subscribed_run_id == run_id ->
        socket

      true ->
        socket = maybe_unsubscribe(socket)
        Phoenix.PubSub.subscribe(NetAuto.PubSub, run_topic(run_id))
        assign(socket, :subscribed_run_id, run_id)
    end
  end

  defp maybe_unsubscribe(%{assigns: %{subscribed_run_id: nil}} = socket), do: socket

  defp maybe_unsubscribe(%{assigns: %{subscribed_run_id: run_id}} = socket) do
    Phoenix.PubSub.unsubscribe(NetAuto.PubSub, run_topic(run_id))
    assign(socket, :subscribed_run_id, nil)
  end

  defp run_topic(run_id), do: "run:#{run_id}"

  defp maybe_update_selected_run(%{assigns: %{selected_run_id: id}} = socket, %{id: id} = run) do
    assign(socket, :selected_run, run)
  end

  defp maybe_update_selected_run(socket, _run), do: socket

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)

  defp fetch_current_user(session) do
    with token when is_binary(token) <- session["user_token"],
         {user, _inserted_at} <- Accounts.get_user_by_session_token(token) do
      user
    else
      _ -> nil
    end
  end

  defp current_user_email(socket) do
    socket.assigns
    |> Map.get(:current_user)
    |> case do
      %{email: email} -> email
      _ -> nil
    end
  end

  defp assign_bulk_context(socket, nil) do
    socket
    |> assign(:bulk_context, nil)
    |> assign(:bulk_context_topic, nil)
  end

  defp assign_bulk_context(socket, ""), do: assign_bulk_context(socket, nil)

  defp assign_bulk_context(socket, ref) do
    socket
    |> maybe_subscribe_bulk(ref)
    |> assign(:bulk_context, %{ref: ref, latest_progress: nil, summary: nil})
  end

  defp maybe_subscribe_bulk(socket, ref) do
    topic = bulk_topic(ref)

    if socket.assigns[:bulk_context_topic] != topic do
      PubSub.subscribe(NetAuto.PubSub, topic)
    end

    assign(socket, :bulk_context_topic, topic)
  end

  defp maybe_update_bulk_progress(
         %{assigns: %{bulk_context: %{ref: ref}, device: %{id: device_id}}} = socket,
         ref,
         %{device_id: device_id} = payload
       ) do
    latest = %{
      status: payload.status,
      run_id: payload.run_id,
      error: payload.error
    }

    assign(socket, :bulk_context, Map.put(socket.assigns.bulk_context, :latest_progress, latest))
  end

  defp maybe_update_bulk_progress(socket, _ref, _payload), do: socket

  defp maybe_update_bulk_summary(%{assigns: %{bulk_context: %{ref: ref}}} = socket, ref, payload) do
    assign(socket, :bulk_context, Map.put(socket.assigns.bulk_context, :summary, %{ok: payload.ok, error: payload.error}))
  end

  defp maybe_update_bulk_summary(socket, _ref, _payload), do: socket

  defp bulk_topic(ref), do: @bulk_topic_prefix <> ref

  defp format_bulk_status(%{status: status, run_id: run_id, error: error}) do
    run_label = if run_id, do: "run ##{run_id}", else: "device"
    base = "#{String.upcase(to_string(status))} #{run_label}"
    if error do
      "#{base} (#{error})"
    else
      base
    end
  end
end
