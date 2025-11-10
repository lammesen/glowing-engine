defmodule NetAutoUiComponents.MixProject do
  use Mix.Project

  def project do
    [
      app: :net_auto_ui_components,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_view, "~> 1.1"}
    ]
  end
end
