# syntax=docker/dockerfile:1.7

# --- build stage ---
FROM hexpm/elixir:1.19.0-rc.1-erlang-26.2.5.11-debian-bullseye-20251103-slim AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git curl nodejs npm && rm -rf /var/lib/apt/lists/*

ENV MIX_ENV=prod
WORKDIR /app

# Preload and compile deps
COPY net_auto/mix.exs net_auto/mix.lock ./
COPY net_auto/config ./config
COPY net_auto_ui_components /net_auto_ui_components
RUN mix local.hex --force && mix local.rebar --force
RUN mix deps.get --only prod && mix deps.compile

# Assets
COPY net_auto/assets ./assets
RUN [ -f assets/package.json ] && npm --prefix assets ci --silent || true
RUN mix assets.deploy

# Source and release
COPY net_auto/lib ./lib
COPY net_auto/priv ./priv
RUN mix compile && mix release

# --- runtime stage ---
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssl ca-certificates ncurses-bin bash libstdc++6 && rm -rf /var/lib/apt/lists/*

ENV MIX_ENV=prod PHX_SERVER=true PORT=8080
WORKDIR /app

RUN useradd --system --create-home --shell /bin/bash app

COPY --from=build --chown=app:app /app/_build/prod/rel/net_auto ./

USER app

EXPOSE 8080
CMD ["/app/bin/net_auto","start"]
