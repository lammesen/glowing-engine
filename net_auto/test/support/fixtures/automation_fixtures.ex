defmodule NetAuto.AutomationFixtures do
  @moduledoc """
  Helpers for run/run_chunk data in tests.
  """

  alias NetAuto.Automation
  alias NetAuto.InventoryFixtures

  def run_fixture(attrs \\ %{}) do
    device = Map.get(attrs, :device) || InventoryFixtures.device_fixture()

    defaults = %{
      command: "show version",
      status: :pending,
      device_id: device.id
    }

    {:ok, run} =
      attrs
      |> Map.drop([:device])
      |> Enum.into(defaults)
      |> Automation.create_run()

    run
  end

  def run_chunk_fixture(attrs \\ %{}) do
    run = Map.get(attrs, :run) || run_fixture()

    defaults = %{run_id: run.id, seq: 0, data: "ok"}

    {:ok, chunk} =
      attrs
      |> Map.drop([:run])
      |> Enum.into(defaults)
      |> Automation.append_chunk()

    chunk
  end
end
