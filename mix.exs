defmodule ElixirAvro.MixProject do
  use Mix.Project

  @source_url "https://github.com/primait/elixir-avro"
  @version "0.1.0"

  def project do
    [
      app: :elixir_avro,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      package: package(),
      deps: deps(),
      docs: docs(),
      dialyzer: [plt_add_apps: [:mix]],
      consolidate_protocols: Mix.env() != :test
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :eex],
      mod: {ElixirAvro.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:avrora, "~> 0.28"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:decimal, "~> 2.0"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:excribe, "~> 0.1.1"},
      {:noether, "~> 0.2.5"},
      {:timex, "~> 3.7.11"},
      {:typedstruct, "~> 0.5.2"},
      {:elixir_uuid, "~> 1.2.1"}
    ]
  end

  defp aliases do
    [
      "format.all": [
        "format mix.exs \"lib/**/*.{ex,exs}\" \"test/**/*.{ex,exs}\" \"priv/**/*.{ex,exs}\""
      ]
    ]
  end

  defp package do
    [
      description: "A to generate Elixir code from Avro schemas",
      maintainers: ["Shared Services"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      extras: [
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: @version,
      formatters: ["html"]
    ]
  end
end
