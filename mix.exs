defmodule Blacksmith.Mixfile do
  use Mix.Project

  def project do
    [
      app: :blacksmith,
      version: "0.1.0",
      elixir: "~> 1.3",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      compilers: [:rustler] ++ Mix.compilers(),
      rustler_crates: rustler_crates(),
      deps: deps()
    ]
  end

  defp rustler_crates do
    [vm: [
      path: "native/vm",
      mode: (if Mix.env == :prod, do: :release, else: :debug),
    ]]
  end

  def application do
    [
      mod: {Blacksmith, []},
      applications: [:cowboy, :ranch, :redix, :plug, :sha3]]
  end

  defp deps do
    [
      {:benchee, "~> 0.11", only: [:dev, :test]},
      {:cbor, "~> 0.1"},
      {:cowboy, "~> 2.3"},
      {:ok, "~> 1.11"},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:distillery, "~> 1.5", runtime: false},
      {:httpoison, "~> 1.1", only: [:dev, :test]},
      {:libsodium, "~> 0.0.10"},
      {:plug, "~> 1.5"},
      {:redix, ">= 0.7.0"},
      {:rustler, "0.16.0"},
      {:sha3, "2.0.0"},
    ]
  end
end
