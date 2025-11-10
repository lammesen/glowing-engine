# Dev HTTPS mkcert Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace Phoenix self-signed PEMs with mkcert-issued certificates and document the workflow so local HTTPS is trusted by default.

**Architecture:** Phoenix dev HTTPS already listens on :4001; we only need to point it to mkcert-generated files under `priv/cert/`, adjust cipher and protocols, and refresh docs. No runtime code changes beyond endpoint config.

**Tech Stack:** Elixir 1.17 / Phoenix 1.8, mkcert CLI, mix tooling.

### Task 1: Generate mkcert cert/key under `priv/cert`

**Files:**
- Modify: `net_auto/priv/cert/localhost-cert.pem` (new mkcert output)
- Modify: `net_auto/priv/cert/localhost-key.pem` (new mkcert output)

**Step 1.1: Remove old self-signed files (optional but keeps folder clean)**
```bash
cd net_auto/priv/cert
rm -f selfsigned.pem selfsigned_key.pem
```
Expected: files removed or message they didn’t exist.

**Step 1.2: Generate mkcert files covering localhost + loopback IPs**
```bash
cd net_auto
mkcert -key-file priv/cert/localhost-key.pem -cert-file priv/cert/localhost-cert.pem localhost 127.0.0.1 ::1
```
Expected: mkcert prints “Created a new certificate valid for the following names…” and writes the two files. These stay gitignored.

### Task 2: Point Phoenix dev config to mkcert files

**Files:**
- Modify: `net_auto/config/dev.exs`

**Step 2.1: Update `https:` block**
- Change `keyfile` → `"priv/cert/localhost-key.pem"`
- Change `certfile` → `"priv/cert/localhost-cert.pem"`
- Set `cipher_suite: :strong` (mkcert cert is trusted; no need for `:compatible`)
- Keep `http_2_options: [enabled: false]` comment or adjust per design (leave as-is if needed)

Snippet to apply:
```elixir
  https: [
    ip: {127, 0, 0, 1},
    port: 4001,
    cipher_suite: :strong,
    keyfile: "priv/cert/localhost-key.pem",
    certfile: "priv/cert/localhost-cert.pem"
  ],
```

**Step 2.2: Ensure surrounding comments mention mkcert (optional)**
Add brief comment like `# mkcert-generated dev cert (see README)` for clarity.

### Task 3: Document mkcert workflow in README

**Files:**
- Modify: `README.md`

**Step 3.1: Update Quick start HTTPS note**
Add bullet describing mkcert requirement and command to regenerate certs under `net_auto/priv/cert`.

Suggested snippet:
```markdown
Need a trusted cert? Run `mkcert -key-file priv/cert/localhost-key.pem -cert-file priv/cert/localhost-cert.pem localhost 127.0.0.1 ::1` inside `net_auto/`.
```

**Step 3.2: Add short section (e.g., “Dev HTTPS”) detailing mkcert install (`mkcert -install` already done) and regeneration steps.

### Task 4: Verify HTTPS locally

**Files:**
- Tests: none automated; manual verification + `mix test`

**Step 4.1: Boot server**
```bash
cd net_auto
mix phx.server
```
Expected: HTTPS listener logs referencing `localhost-cert.pem`; no `ENOENT` errors.

**Step 4.2: Browser check**
Visit `https://localhost:4001` and ensure browser trusts the cert (no warning). Note result.

**Step 4.3: Run automated tests as smoke check**
```bash
mix test
```
Expected: All tests pass.

**Step 4.4: Commit**
```bash
git status -sb
# ensure only intended files changed (README, config, new PEMs ignored)
git add net_auto/config/dev.exs README.md docs/plans/2025-11-08-dev-https-mkcert-impl.md docs/plans/2025-11-08-dev-https-mkcert.md
# PEMs remain untracked
git commit -m "chore(dev): switch HTTPS certs to mkcert"
```
