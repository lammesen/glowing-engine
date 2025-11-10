import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/net_auto start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
grafana_host = System.get_env("PROMEX_GRAFANA_URL")
grafana_token = System.get_env("PROMEX_GRAFANA_API_KEY")
grafana_folder = System.get_env("PROMEX_GRAFANA_FOLDER") || "NetAuto"

parse_positive_integer = fn
  nil, default ->
    default

  value, default ->
    case Integer.parse(value) do
      {int, _} when int > 0 -> int
      _ -> default
    end
end

retention_cron = System.get_env("NET_AUTO_RETENTION_CRON") || "@daily"
max_age_days = parse_positive_integer.(System.get_env("NET_AUTO_RUN_MAX_DAYS"), 30)
max_total_bytes = parse_positive_integer.(System.get_env("NET_AUTO_RUN_MAX_BYTES"), 1_073_741_824)

config :net_auto, NetAuto.Automation.Retention,
  max_age_days: max_age_days,
  max_total_bytes: max_total_bytes

config :net_auto, Oban,
  repo: NetAuto.Repo,
  queues: [default: 10, retention: 5, bulk: 5],
  plugins: [
    {Oban.Plugins.Cron, crontab: [{retention_cron, NetAuto.Automation.RetentionWorker}]}
  ]

if grafana_host && grafana_token do
  config :net_auto, NetAuto.PromEx,
    grafana: [
      host: grafana_host,
      auth_token: grafana_token,
      upload_dashboards_on_start: true,
      folder_name: grafana_folder
    ],
    manual_metrics_start_delay: :timer.seconds(10)
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL is missing (e.g., ecto://USER:PASS@HOST/DATABASE?sslmode=require)"

  pool_size = String.to_integer(System.get_env("POOL_SIZE") || "5")

  config :net_auto, NetAuto.Repo,
    url: database_url,
    pool_size: pool_size,
    ssl: true

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "8080")

  config :net_auto, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :net_auto, NetAutoWeb.Endpoint,
    url: [host: host, scheme: "https", port: 443],
    http: [ip: {0, 0, 0, 0}, port: port]

  if System.get_env("PHX_SERVER") do
    config :net_auto, NetAutoWeb.Endpoint, server: true
  end

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "SECRET_KEY_BASE is missing"

  config :net_auto, NetAutoWeb.Endpoint, secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :net_auto, NetAutoWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :net_auto, NetAutoWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :net_auto, NetAuto.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
