# Fly.io + Neon Deployment

Deploy `net_auto/` to Fly.io as a Mix release that talks to your Neon-hosted Postgres instance. The Dockerfile under `net_auto/` builds the release, while `fly.toml` configures services and runs database migrations before each deploy.

## One-time setup

```bash
# Create the Fly app (idempotent)
flyctl apps create netauto || true

# Store secrets (Neon URL uses the pooled endpoint)
flyctl secrets set \
  DATABASE_URL="postgres://<user>:<pass>@<neon-project>-pooler.neon.tech/<db>?sslmode=require" \
  SECRET_KEY_BASE="$(mix phx.gen.secret)" \
  PHX_HOST="netauto.fly.dev" \
  PHX_SERVER=true \
  POOL_SIZE=5
```

## Deploy + operations

```bash
# Build + deploy using the Dockerfile in net_auto/
flyctl deploy --config ./fly.toml --detach

# Check machine + health status
flyctl status

# Tail logs if something misbehaves
flyctl logs
```

The `[deploy]` block in `fly.toml` runs database migrations each time via:
```
/app/bin/net_auto eval 'Elixir.NetAuto.Release.migrate()'
```
If the migration fails, Fly aborts the deployment.

## Smoke test

```bash
curl -sSf https://netauto.fly.dev/ | head -n 5
```

Use your actual Fly app name/host if it differs from `netauto`. Secrets (including `DATABASE_URL` and `SECRET_KEY_BASE`) must be managed through `flyctl secrets`; never commit them to git.
