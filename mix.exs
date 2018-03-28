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
      applications: [:cowboy, :ranch, :redix]]
  end

  defp deps do
    [
      {:distillery, "~> 1.5", runtime: false},
      {:rustler, "0.16.0"},
      {:cowboy, "~> 2.2.0"},
      {:redix, ">= 0.7.0"},
      {:cbor, [path: "../elixir-cbor"]},
      {:libsodium, "~> 0.0.10"},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:benchee, "~> 0.11", only: [:dev, :test]},
      {:httpoison, "~> 1.0", only: [:dev, :test]},
    ]
  end
end
