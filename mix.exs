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
    [mod: {BlacksmithApp, []}, applications: [:lager, :logger, :grpc]]
  end

  defp deps do
    [
      {:grpc, github: "tony612/grpc-elixir"},
      # {:grpc, path: "../../"},
      {:rustler, "0.16.0"},
      # {:rox, "~> 1.0"},
      {:ed25519, "~> 1.2.0"},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:benchee, "~> 0.11", only: [:dev, :test]}
    ]
  end
end
