defmodule Scry.MixProject do
  use Mix.Project

  @documentation "https://docs.dupunkto.org/scry"
  @git_repository "https://git.dupunkto.org/~dupunkto/scry"

  def project do
    [
      name: "Scry",
      app: :scry,
      version: "0.0.1",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      source_url: @git_repository,
      homepage_url: @documentation,
      description: description(),
      package: package(),
      docs: docs() 
    ]
  end

  def description do
    "In-house version control system."
  end

  defp package do
    [
      licenses: ["Unlicense"],
      links: %{"Sources" => @git_repository}
    ]
  end

  def application do
    [
      mod: {Scry.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7.21"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.5"},
      {:structo, "~> 0.2.1"},

      # For documentation :)
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "Scry",
      api_reference: false,
      authors: ["Robijntje"],
      formatters: ["html"]
    ]
  end
end
