defmodule NetAuto.PromExTest do
  use ExUnit.Case, async: true

  test "promex module exposes plugins and dashboards" do
    assert function_exported?(NetAuto.PromEx, :plugins, 0)
    assert function_exported?(NetAuto.PromEx, :dashboards, 0)
  end
end
