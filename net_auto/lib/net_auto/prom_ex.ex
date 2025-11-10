defmodule NetAuto.PromEx do
  @moduledoc """
  PromEx entrypoint for NetAuto, responsible for exposing telemetry metrics
  and uploading dashboards to Grafana when configured.
  """

  use PromEx, otp_app: :net_auto

  alias NetAuto.PromEx.ObservabilityPlugin
  alias NetAutoWeb.{Endpoint, Router}

  @impl true
  def plugins do
    base = [
      PromEx.Plugins.Application,
      PromEx.Plugins.Ecto
    ]

    oban_plugins =
      if oban_enabled?() do
        [PromEx.Plugins.Oban]
      else
        []
      end

    base ++
      oban_plugins ++
      [
        {PromEx.Plugins.Phoenix, router: Router, endpoint: Endpoint},
        {PromEx.Plugins.PhoenixLiveView, router: Router, endpoint: Endpoint},
        {ObservabilityPlugin, metric_prefix: [:net_auto, :runner]}
      ]
  end

  @impl true
  def dashboards do
    [
      dashboards_dir: "lib/net_auto/prom_ex/dashboards"
    ]
  end

  defp oban_enabled? do
    Application.get_env(:net_auto, Oban, [])
    |> Keyword.get(:queues)
    |> Kernel.!=(false)
  end
end
