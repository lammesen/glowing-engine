# WS06 Chelekom Foundation – Design (2025-11-08)

## Generator & Imports
- Run `mix mishka.ui.gen.components --import --helpers --global --yes` inside `net_auto/`. This copies all Chelekom components/helpers, creates `NetAutoWeb.MishkaImports`, and rewires `lib/net_auto_web.ex` so every controller/view/live_view pulls in Chelekom primitives.
- Keep `NetAutoWeb.CoreComponents` for bespoke widgets, but default components now come from Mishka. After the generator, ensure `html_helpers/0` imports both `NetAutoWeb.MishkaImports` (primary) and any legacy helpers still needed.
- Commit all generated modules under `lib/net_auto_web/components/mishka_*`, the helper hook modules, and the `priv/mishka_chelekom/config.exs` token file. Note in docs that future component overrides belong in these directories.

## Assets & Tokens
- The generator outputs Mishka CSS/JS assets (e.g., `assets/vendor/mishka_chelekom.css`, `assets/js/mishka_components.js`). Import them alongside existing Tailwind/daisyUI plugins so we can fall back if something breaks. Example `app.css` order: Mishka vendor CSS, Tailwind directives, heroicons plugin, existing daisyUI plugins.
- Import the Mishka JS module in `assets/js/app.js` before LiveView hooks to register Chelekom-specific behavior.
- Leave `priv/mishka_chelekom/config.exs` as the canonical place for theme tokens (colors, radii, typography). Document in README/project plan that brand tweaks should happen there, not via ad-hoc CSS.

## Validation & Docs
- After generation, run `mix test`, `mix tailwind net_auto`, and `mix esbuild net_auto` (via `mix assets.build`) to ensure assets compile with the new imports. Sanity check `/` and `/devices` via `mix phx.server`.
- Add a short note to project docs (or this plan) describing how to rerun the generator if new components are added, and warn other workstreams not to run the global generator again without coordination.
