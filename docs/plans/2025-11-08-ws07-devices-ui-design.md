# WS07 Devices UI – Design (2025-11-08)

## Overview & Data Flow

- Devices UI lives under a new authenticated `live_session :operators` scope with `/devices` mounting `NetAutoWeb.DeviceLive.Index`. Modal routes `/devices/new` and `/devices/:id/edit` are handled via live navigation; they never leave the index LiveView.
- `DeviceLive.Index` assigns `%{query: "", sort_by: :hostname, sort_dir: :asc}` and subscribes to `"inventory:devices"` when connected. It streams rows via `stream(:devices, [])` so external changes can insert/update/delete rows without full reload.
- WS07 adds `Inventory.search_devices/1`, which composes an Ecto query from filters. Search uses `ilike` across hostname, ip, vendor, model, site, username, and `fragment("?::text", d.tags)` for tags. Sorting relies on whitelisted atoms to prevent SQL injection. `handle_params/3` updates filters from URL params and refreshes data through this helper.
- Inventory broadcasts `{:device, action, device}` on `"inventory:devices"` after create/update/delete. The LiveView handles these messages with `stream_insert`/`stream_delete`, keeping the table live even when other contexts mutate devices.

## LiveView Structure & Events

- `mount/3` assigns filters, an empty stream, and modal state. `handle_params/3` handles `q`, `sort`, and `dir`, merges into filters, and calls `load_devices/1` to `stream_reset` with search results.
- Search input uses `phx-change="search"` with debounce to push params updates (`push_patch`) so filters stay in URL. Sorting buttons fire `"sort"` events that toggle direction and push params.
- PubSub messages from Inventory update the stream. `{:device, :created, device}` inserts at top; `:updated` re-inserts; `:deleted` removes.
- Modals: clicking “Add Device” or “Edit” triggers live navigation (`push_patch` to `/devices/new` or `/devices/:id/edit`). The LiveView assigns `%{mode: :new | :edit, device: struct}` which toggles `<.modal>` rendering. A nested `DeviceFormComponent` wraps `Inventory.change_device/1`, validates inline, and sends `{:saved, device}`. `Index` closes the modal, pushes back to `/devices`, refreshes the stream, and flashes a Chelekom toast.

## UI Layout & Components

- Template wraps content in `<Layouts.app flash={@flash} current_scope={@current_scope}>`.
- Header bar: title on left, unified search input plus “Add Device” primary button on right. Search uses Chelekom `input_field` with left search icon and debounce hint text.
- Filter strip reserved for future chips (Chelekom `badge` components) but currently houses placeholder container so layout remains stable.
- Devices table: Chelekom `table` with sortable headers (buttons containing label + sort icon). Columns—Hostname, IP, Protocol (badge), Site, Username, Vendor/Model, Last Run (placeholder), Actions. Rows render via `stream` assigns; protocol uses colored badges, hostname bolds primary text.
- Actions column includes “Edit” ghost button triggering modal navigation.
- Modals use Chelekom `modal` with two-column form (responsive). Form uses `form_wrapper`, `input_field` for text fields (hostname, ip, username, vendor, model, site), `select` for protocol, number input for port, textarea for tags JSON. Buttons: “Save Device” (primary) and “Cancel” (default). Toasts use Chelekom `<.toast>` triggered via flash.
