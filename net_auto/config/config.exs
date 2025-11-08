# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :net_auto, :scopes,
  user: [
    default: true,
    module: NetAuto.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: NetAuto.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :net_auto,
  ecto_repos: [NetAuto.Repo],
  generators: [timestamp_type: :utc_datetime]

config :net_auto, NetAuto.Secrets,
  adapter: NetAuto.Secrets.Env,
  adapters: [env: NetAuto.Secrets.Env]
config :net_auto, NetAuto.Protocols, adapter: NetAuto.Protocols.SSHAdapter
config :net_auto, NetAuto.Protocols.SSHAdapter, ssh: NetAuto.Protocols.SSHEx

config :net_auto, NetAuto.PromEx,
  grafana: :disabled,
  manual_metrics_start_delay: :timer.seconds(10)

config :net_auto, :network_client, NetAuto.Network.LocalRunner

config :net_auto, NetAuto.Automation,
  global_limit: 50,
  site_limits: %{},
  default_site_limit: 5

config :net_auto, Oban,
  repo: NetAuto.Repo,
  queues: [default: 10, retention: 5, bulk: 5],
  plugins: [
    {Oban.Plugins.Cron, crontab: [{"@daily", NetAuto.Automation.RetentionWorker}]}
  ]

# Configures the endpoint
config :net_auto, NetAutoWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: NetAutoWeb.ErrorHTML, json: NetAutoWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: NetAuto.PubSub,
  live_view: [signing_salt: "05T7ZIZm"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :net_auto, NetAuto.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  net_auto: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  net_auto: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
