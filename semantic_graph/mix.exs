defmodule SemanticGraph.MixProject do
  use Mix.Project

  @app :semantic_graph

  def project do
    [
      app: @app,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      # Gleam holds kernels: pure, total modules where being wrong is a
      # violation. See agent-icm context/30-stack/10-gleam-kernels.md, and
      # docs/architecture/ADR-008-gleam-for-kernels.md for this repository's
      # adoption. The :gleam compiler runs first; Ash adds no compiler of its
      # own, so there is nothing for it to collide with.
      archives: [mix_gleam: "~> 0.6"],
      compilers: [:gleam | Mix.compilers()],
      erlc_paths: ["build/dev/erlang/#{@app}/_gleam_artefacts"],
      erlc_include_path: "build/dev/erlang/#{@app}/include",
      prune_code_paths: false,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {SemanticGraph.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Phoenix and Web
      {:phoenix, "~> 1.7.10"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.1"},
      {:phoenix_live_dashboard, "~> 0.8.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},

      # Ash Framework
      {:ash, "~> 3.0"},
      {:ash_json_api, "~> 1.0"},
      {:ash_postgres, "~> 2.0"},

      # Gleam
      {:gleam_stdlib, "~> 0.34 or ~> 1.0"},
      {:gleeunit, "~> 1.0", only: [:dev, :test], runtime: false},

      # TUI
      {:ratatouille, "~> 0.5.0"},

      # HTTP Client
      {:tesla, "~> 1.8"},
      {:hackney, "~> 1.18"},

      # JSON
      {:jason, "~> 1.4"},

      # Utilities
      {:plug_cowboy, "~> 2.5"},
      {:gettext, "~> 0.20"},

      # Development and Testing
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      # gleam.deps.get resolves the Gleam side; both must run.
      "deps.get": ["deps.get", "gleam.deps.get"],
      setup: ["deps.get", "ecto.create", "ecto.migrate"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
