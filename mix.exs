defmodule Blacksmith.Mixfile do
  use Mix.Project

  def project do
    [
      app: :blacksmith,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      compilers: [:rustler] ++ Mix.compilers(),
      rustler_crates: rustler_crates(),
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  defp rustler_crates do
    [
      vm_nif: [
        path: "native/vm_nif",
        mode: if(Mix.env() == :prod, do: :release, else: :debug)
      ],
      transaction_processor: [
        path: "native/transaction_processor",
        mode: if(Mix.env() == :prod, do: :release, else: :debug)
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      mod: {Blacksmith.Application, []},
      extra_applications: extra_applications(Mix.env())
    ]
  end

  defp extra_applications(:dev), do: extra_applications(:all) ++ [:remix]
  defp extra_applications(_all), do: [:cowboy, :ranch, :redix, :plug]
  defp extra_applications(_all), do: []

  defp deps do
    [
      {:abi, "~> 0.1"},
      {:artificery, [env: :prod, github: "mana-ethereum/artificery", branch: "hayesgm/allow-extra-args", override: true]},
      {:benchee, "~> 0.11", only: [:dev, :test]},
      {:binary, "~> 0.0.5"},
      {:bypass, "~> 0.8", only: :test},
      {:cbor, "~> 0.1"},
      {:cors_plug, "~> 1.5"},
      {:cowboy, "~> 2.3"},
      {:dialyxir, "~> 1.0.0-rc.3", only: [:dev, :test], runtime: false},
      {:distillery, "~> 2.0", runtime: false},
      {:ecto, "~> 3.0"},
      {:ecto_sql, "~> 3.0-rc.1"},
      {:ethereumex,
      [github: "masonforest/ethereumex", branch: "websocket-client", override: true]},
      {:ex_machina, "~> 2.2"},
      {:exth_crypto, "~> 0.1.4", override: true},
      {:exw3, github: "masonforest/exw3", branch: "websocket-client"},
      {:httpoison, "~> 1.3"},
      {:keccakf1600, hex: :keccakf1600_orig},
      {:libsodium, "~> 0.0.10"},
      {:mana, [github: "mana-ethereum/mana", app: false]},
      {:ok, "~> 2.0"},
      {:plug, "~> 1.5"},
      {:plug_cowboy, "~> 2.0"},
      {:poison, "~> 4.0", override: true},
      {:postgrex, "~> 0.14.0"},
      {:redix, "0.8.0"},
      {:redix_pubsub, "~> 0.5.0"},
      {:remix, "~> 0.0.1", only: :dev},
      # Until [this PR](https://github.com/hansihe/rustler/pull/166) is merged
      # Use [this branch](https://github.com/cristianberneanu/rustler)
      {:rustler, [path: "./priv/rustler/rustler_mix", override: true]},
      {:websockex, [env: :prod, github: "mana-ethereum/websockex", branch: "master", override: true]},
    ]
  end
end
