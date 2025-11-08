# WS08 Run UI Design

## Intent
Deliver the `/devices/:id` Run workspace so operators can launch commands, view their streaming output, and browse historical runs without leaving the page. The LiveView must call `NetAuto.Network.execute_command/3` directly so it stays aligned with WS05’s runner surface.

## Layout Summary
- **Two-column grid:** Left column (~35%) hosts the Run History panel. Right column (~65%) holds the run form and a tabbed card for the active run.
- **History card:** Uses Chelekom `card`, `table`, and `badge` components (once WS06 lands). Each entry shows command preview, status badge, operator, timestamps, and selection affordance. Selecting an entry keeps the user’s current tab (Live Output or Run Details).
- **Filters:** Inline form stacked above the history list. Fields: status multi-select, requested_by dropdown (populated from recent runs), date range (from/to), and free-text search (command/device/site). Filters update results without changing pagination.

## Active Run Panel
- **Command form:** Device context banner, textarea for command, optional `select` for templates, and primary button wired to `NetAuto.Network.execute_command/3`. Shows in-form validation errors; success toasts when the run begins.
- **Tabs:** Chelekom `tabs` component with two tabs: “Live Output” (monospaced stream view with auto-scroll toggle) and “Run Details” (metadata grid: status badge, started/finished times, bytes, command template, operator, exit code, error reason if any). Tab choice persists per-user session via assign or hidden param.
- **Live Output card:** Stream chunks via Phoenix Streams keyed by chunk seq. Scroll container auto-scrolls only when the user pin is enabled; otherwise, it leaves scroll position untouched.

## Data & Streaming
- Subscribe to `"run:#{run.id}"` topic on mount for the selected run. Handle `{:chunk, run_id, seq, data}` events by inserting/updating the stream and incrementing byte counts. Handle completion events (e.g., `{:run_finished, run}`) to refresh metadata and history list.
- Maintain `selected_run_id`, `history_filters`, and `history_page` in socket assigns. When filters/page change, re-query history via new context helper `Automation.paginated_runs_for_device/2` that enforces device scoping, applies filters, and returns `{runs, pagination}`.
- Preload `:device` and `:chunks` as necessary; chunk list remains paginated separately via `run_chunks` query (`Automation.list_run_chunks(run_id)` already exists).

## UX Notes
- Default selection is the most recent run, but UI does not auto-jump when new runs start; instead, display a subtle toast/badge offering “Follow latest run”.
- History list exposes info badges for statuses; filtering updates via debounce to avoid excess DB hits.
- “Live Output” tab includes copy-to-clipboard button and `clear` action only for UI state (does not delete chunks).

## Testing Considerations
- Context tests covering filtering, pagination ordering, and search semantics.
- LiveView tests verifying: auth requirement, history filters, selection persistence, command submission calling `NetAuto.Network.execute_command/3`, and handling of PubSub chunk events via `Phoenix.PubSub.broadcast_from/4`.
- Accessibility: tabs and forms include ARIA labels; ensure focus styles for history selection.
