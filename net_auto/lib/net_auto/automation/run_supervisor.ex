defmodule NetAuto.Automation.RunSupervisor do
  @moduledoc """
  Dynamic supervisor responsible for per-run processes.
  """

  use DynamicSupervisor

  @name __MODULE__

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
