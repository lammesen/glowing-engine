defmodule NetAuto.Automation.RunSupervisorTest do
  use ExUnit.Case, async: false

  alias NetAuto.Automation.RunSupervisor

  test "starts dynamic children" do
    start_supervised!({RunSupervisor, name: __MODULE__})

    {:ok, pid} =
      DynamicSupervisor.start_child(__MODULE__, {Task, fn -> :ok end})

    assert is_pid(pid)
    refute Process.alive?(pid)
  end
end
