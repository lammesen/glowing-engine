#!/usr/bin/env bash
set -euo pipefail

APP_NAME="net_auto"
DB="postgres"

echo "==> Checking prerequisites..."
command -v mix >/dev/null || { echo "mix not found. Install Elixir/Erlang."; exit 1; }

echo "==> Generating Phoenix project ($APP_NAME) with LiveView..."
mix phx.new "$APP_NAME" --database "$DB" --live --no-mailer --no-dashboard --quiet

cd "$APP_NAME"
git init -q && git add . && git commit -q -m "chore: initial phoenix app"

echo "==> Injecting dependencies (Oban/PromEx/Mishka Chelekom)..."
if ! grep -q 'mishka_chelekom' mix.exs; then
  awk '
    /defp deps do/ { inblock=1 }
    inblock==1 && /^\s*\]/ && added!=1 {
      print "      {:oban, \\"~> 2.17\\"},"
      print "      {:prom_ex, \\"~> 1.10\\"},"
      print "      {:mishka_chelekom, \\"~> 0.0.8\\", only: :dev}"
      added=1
    }
    { print }
    inblock==1 && /^\s*end\s*$/ { inblock=0 }
  ' mix.exs > mix.exs.tmp && mv mix.exs.tmp mix.exs
fi

mix deps.get

echo "==> Generating auth (phx.gen.auth)..."
mix phx.gen.auth Accounts User users --binary-id || true
mix deps.get

echo "==> Running Mishka Chelekom generator..."
MIX_ENV=dev mix mishka.ui.gen.components --import --helpers --global --yes || {
  echo "WARN: Chelekom generator failed; run mix deps.get and rerun the generator."
}

echo "==> Copying overlay code (contexts, OTP runners, LiveViews)..."
SRC_OVERLAY="../overlay"
mkdir -p lib
cp -R "$SRC_OVERLAY/lib/." "lib/"

echo "==> Overwriting application.ex to include supervisors..."
cp -f "$SRC_OVERLAY/lib/net_auto/application.ex" "lib/net_auto/application.ex"

echo "==> Inserting LiveView routes into router.ex..."
mkdir -p scripts
cp -f "../scripts/insert_routes.exs" "scripts/insert_routes.exs"
mix run scripts/insert_routes.exs

echo "==> Creating migrations (devices, groups/templates/runs/chunks)..."
python3 ../scripts/write_migrations.py

echo "==> Running migrations..."
mix ecto.create || true
mix ecto.migrate

echo "Bootstrap complete."
echo "Next:"
echo "  cd net_auto"
echo "  export NET_AUTO_LAB_DEFAULT_PASSWORD=changeme"
echo "  mix phx.server"
