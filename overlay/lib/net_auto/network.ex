defmodule NetAuto.Network do
  alias NetAuto.Automation
  alias NetAuto.Automation.RunServer

  @doc "Create a Run and start a supervised process that streams output."
  def execute_command(device_id, command, attrs \\ %{}) do
    run = Automation.create_running_run!(device_id, command, attrs)
    {:ok, _pid} = RunServer.start_child(run_id: run.id)
    {:ok, run}
  end
end
