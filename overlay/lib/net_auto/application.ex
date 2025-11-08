defmodule NetAuto.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      NetAuto.Repo,
      NetAutoWeb.Telemetry,
      {Phoenix.PubSub, name: NetAuto.PubSub},
      NetAutoWeb.Endpoint,
      {DynamicSupervisor, name: NetAuto.RunSupervisor, strategy: :one_for_one},
      NetAuto.Automation.QuotaServer
    ]

    opts = [strategy: :one_for_one, name: NetAuto.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    NetAutoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
