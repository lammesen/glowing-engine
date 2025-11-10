# Dev HTTPS with mkcert (WS01)

## Context
- Local HTTPS currently uses Phoenix self-signed PEMs (`priv/cert/selfsigned*.pem`).
- mkcert has been installed and the CA is trusted, but cert/key files were not generated for this repo.
- Browsers show warnings when certs aren’t trusted; we want mkcert-issued certs bound to localhost loopback addresses.

## Requirements
1. Generate mkcert certificates under `net_auto/priv/cert/` so they stay out of git and match Phoenix defaults.
2. Update `config/dev.exs` to point the HTTPS config at the mkcert files and prefer strong cipher suites (HTTP/2 optional toggle).
3. Document the regeneration process in `README.md` so other contributors can recreate certs without guesswork.
4. Verify `mix phx.server` can boot with the mkcert certificate and browsers load HTTPS without warnings.

## Approach
- Remove/replace `selfsigned*.pem` in `net_auto/priv/cert/` with mkcert-generated files named `localhost-cert.pem` + `localhost-key.pem` (covers `localhost`, `127.0.0.1`, `::1`).
- Run `mkcert -key-file net_auto/priv/cert/localhost-key.pem -cert-file net_auto/priv/cert/localhost-cert.pem localhost 127.0.0.1 ::1` from repo root (or within `net_auto`).
- Point `config/dev.exs` HTTPS block to the new filenames, set `cipher_suite: :strong`, and keep `http_2_options` + URL overrides tuned for dev.
- Expand README instructions with mkcert steps so new contributors can reproduce the trusted cert setup quickly.

## Testing & Verification
- Boot dev server via `cd net_auto && mix phx.server`; ensure HTTPS listener starts without errors referencing `localhost-cert.pem`.
- Visit `https://localhost:4001` in a browser; confirm the cert is trusted (no warnings) and the app loads normally.
- Optionally run `mix test` to ensure unrelated changes remain green.

## Risks / Notes
- mkcert certificates expire (default 825 days); include command in README so regenerating is trivial.
- Files remain untracked (ignored by default); contributors must regenerate locally—documented steps mitigate confusion.
- If additional hostnames are needed later (e.g., custom domains), rerun mkcert with extra SANs and update config if paths change.
