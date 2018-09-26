defmodule Blacksmith.Mixfile do
  use Mix.Project

  def project do
    [
      app: :blacksmith,
      version: "0.1.0",
      elixir: "~> 1.7",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      compilers: [:rustler] ++ Mix.compilers(),
      rustler_crates: rustler_crates(),
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env),
    ]
  end

  defp rustler_crates do
    [vm: [
      path: "native/vm",
      mode: (if Mix.env == :prod, do: :release, else: :debug),
    ]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      mod: {Blacksmith.Application, []},
      extra_applications: [:cowboy, :ranch, :redix, :plug, :sha3]]
  end

  defp deps do
    [
      {:benchee, "~> 0.11", only: [:dev, :test]},
      {:cbor, "~> 0.1"},
      {:cors_plug, "~> 1.5"},
      {:cowboy, "~> 2.3"},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:distillery, "~> 1.5", runtime: false},
      {:ecto, "~> 2.2"},
      {:ex_machina, "~> 2.2", only: :test},
      {:httpoison, "~> 1.1", only: [:dev, :test]},
      {:libsodium, "~> 0.0.10"},
      {:ok, "~> 1.11"},
      {:plug, "~> 1.5"},
      {:postgrex, "~> 0.13.0" },
      {:redix, ">= 0.7.0"},
      {:rustler, "0.16.0"},
      {:sha3, "2.0.0"}
    ]
  end
end
