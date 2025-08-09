defmodule MsgpackElixir.MixProject do
  use Mix.Project

  @version "1.1.0"
  @source_url "https://github.com/nrednav/msgpack_elixir"

  def project do
    [
      app: :msgpack_elixir,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: "A MessagePack serialization library for Elixir.",
      package: package(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger, :telemetry]
    ]
  end

  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:telemetry, "~> 1.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:stream_data, "~> 1.0", only: :test},
      {:benchee, "~> 1.0", only: :dev}
    ]
  end

  defp aliases do
    [
      check: ["format --check-formatted", "credo", "test"]
    ]
  end

  defp package do
    [
      maintainers: ["Vandern Rodrigues"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => @source_url <> "/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp docs do
    [
      main: "Msgpack",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "guides/telemetry.md"
      ]
    ]
  end
end
