# syntax=docker/dockerfile:1.7

# --- build stage ---
FROM hexpm/elixir:1.19.0-erlang-27.1-debian-bookworm-20240902 AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git curl nodejs npm && rm -rf /var/lib/apt/lists/*

ENV MIX_ENV=prod
WORKDIR /app

# Preload and compile deps
COPY net_auto/mix.exs net_auto/mix.lock ./
COPY net_auto/config ./config
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
    openssl ca-certificates ncurses bash libstdc++6 && rm -rf /var/lib/apt/lists/*

ENV MIX_ENV=prod PHX_SERVER=true PORT=8080
WORKDIR /app

RUN useradd --system --create-home --shell /bin/bash app

COPY --from=build --chown=app:app /app/_build/prod/rel/net_auto ./

USER app

EXPOSE 8080
CMD ["/app/bin/net_auto","start"]
