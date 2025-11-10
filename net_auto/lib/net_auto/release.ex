defmodule NetAuto.Release do
  @moduledoc "Runtime release helpers for Fly and other deployments."
  @app :net_auto

  def migrate do
    Application.load(@app)

    for repo <- Application.fetch_env!(@app, :ecto_repos) do
      Ecto.Migrator.with_repo(repo, fn repo ->
        Ecto.Migrator.run(repo, :up, all: true)
      end)
    end
  end
end
