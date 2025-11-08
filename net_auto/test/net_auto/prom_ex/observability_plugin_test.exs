defmodule NetAuto.PromEx.ObservabilityPluginTest do
  use ExUnit.Case, async: true

  alias NetAuto.PromEx.ObservabilityPlugin

  test "runner plugin exposes event metrics" do
    assert [_ | _] = ObservabilityPlugin.event_metrics(metric_prefix: [:net_auto, :runner])
  end
end
