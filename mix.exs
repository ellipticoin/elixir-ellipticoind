defmodule Ellipticoind.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ellipticoind,
      version: "0.1.1",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      compilers: [:rustler, :golang] ++ Mix.compilers(),
      rustler_crates: rustler_crates(),
      golang_modules: golang_modules(),
      deps: deps(),
      releases: releases(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def releases do
    [
      ellipticoind: [
        config_providers: [{JSONConfigProvider, "/usr/local/etc/ellipticoind.json"}]
      ]
    ]
  end

  defp golang_modules do
    [
      libp2p: [
        path: "native/libp2p",
        install_args: ["libp2p.go", "pubsub.go"]
      ]
    ]
  end

  defp rustler_crates do
    [
      transaction_processor: [
        path: "native/transaction_processor",
        mode: if(Mix.env() == :prod, do: :release, else: :debug)
      ],
      hashfactor: [
        path: "native/hashfactor",
        mode: if(Mix.env() == :prod, do: :release, else: :debug)
      ],
      ed25519: [
        path: "native/ed25519",
        mode: if(Mix.env() == :prod, do: :release, else: :debug)
      ],
      rocksdb: [
        path: "native/rocksdb",
        mode: if(Mix.env() == :prod, do: :release, else: :debug)
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      mod: {Ellipticoind.Application, []},
      extra_applications: extra_applications(Mix.env())
    ]
  end

  defp extra_applications(:dev), do: extra_applications(:all) ++ [:remix]
  defp extra_applications(_all), do: [:cowboy, :ranch, :redix, :plug]

  defp deps do
    [
      {:jason, "~> 1.1"},
      {:benchee, "~> 0.11", only: [:dev, :test]},
      {:binary, "~> 0.0.5"},
      {:bypass, "~> 1.0", only: :test},
      {:cbor, "~>  0.1.8"},
      {:cors_plug, "~> 2.0"},
      {:cowboy, "~> 2.6"},
      {:decimal, "~> 1.7"},
      {:ecto, "~> 3.1.7"},
      {:ecto_sql, "~> 3.1.3"},
      {:ex_machina, "~> 2.2"},
      {:golang_compiler, "~> 0.2.1"},
      {:httpoison, "~> 1.4"},
      {:ok, "~> 2.0"},
      {:phoenix, "~> 1.4.0"},
      {:phoenix_ecto, "~> 4.0"},
      {:plug, "~> 1.5"},
      {:plug_cowboy, "~> 2.0"},
      {:poison, "~> 4.0"},
      {:postgrex, "~> 0.14.3"},
      {:redix, "0.8.0"},
      {:remix, "~> 0.0.1", only: :dev},
      {:rustler, "0.19.0"},
      {:temporary_env, "~> 2.0", only: :test, runtime: false},
      {:exprotobuf, "~> 1.2.9"}
    ]
  end
end
