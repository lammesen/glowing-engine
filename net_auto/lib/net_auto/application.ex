defmodule NetAuto.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      NetAutoWeb.Telemetry,
      NetAuto.Repo,
      {DNSCluster, query: Application.get_env(:net_auto, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: NetAuto.PubSub},
      {Registry, keys: :unique, name: NetAuto.Automation.Registry},
      NetAuto.Automation.QuotaServer,
      NetAuto.Automation.RunSupervisor,
      NetAutoWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NetAuto.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    NetAutoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
