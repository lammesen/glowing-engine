# syntax=docker/dockerfile:1.7

# --- Builder ---------------------------------------------------------------
FROM hexpm/elixir:1.19.0-erlang-27.0-debian-bookworm-20241015 AS build

ENV MIX_ENV=prod \
    LANG=C.UTF-8
WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only $MIX_ENV && mix deps.compile

COPY assets assets
COPY priv priv
COPY lib lib

RUN MIX_ENV=$MIX_ENV mix assets.deploy
RUN MIX_ENV=$MIX_ENV mix release

# --- Runtime --------------------------------------------------------------
FROM debian:bookworm-slim AS app

ENV LANG=C.UTF-8 \
    MIX_ENV=prod \
    PHX_SERVER=true \
    PORT=4000 \
    SHELL=/bin/bash

RUN apt-get update \
  && apt-get install -y --no-install-recommends libstdc++6 openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/* \
  && useradd --system --create-home --shell /bin/bash app

WORKDIR /app

COPY --from=build /app/_build/prod/rel/net_auto ./net_auto
RUN chown -R app:app /app
USER app

EXPOSE 4000
CMD ["/app/net_auto/bin/net_auto", "start"]
