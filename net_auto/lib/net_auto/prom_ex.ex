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
    [
      PromEx.Plugins.Application,
      PromEx.Plugins.Ecto,
      PromEx.Plugins.Oban,
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
end
