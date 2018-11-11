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
      mod: {Blacksmith.Application, application_args()},
      extra_applications: extra_applications(Mix.env())
    ]
  end

  def application_args do
    [
      Application.fetch_env!(:blacksmith, :port),
      Application.fetch_env!(:blacksmith, :ethereum_private_key),
    ]
  end

  defp extra_applications(:dev), do: extra_applications(:all) ++ [:remix]
  defp extra_applications(_all), do: [:cowboy, :ranch, :redix, :plug, :sha3]

  defp deps do
    [
      {:benchee, "~> 0.11", only: [:dev, :test]},
      {:cbor, "~> 0.1"},
      {:abi, "~> 0.1"},
      {:bypass, "~> 0.8", only: :test},
      {:cors_plug, "~> 1.5"},
      {:cowboy, "~> 2.3"},
      {:dialyxir, "~> 1.0.0-rc.3", only: [:dev, :test], runtime: false},
      {:distillery, "~> 2.0", runtime: false},
      {:ecto, "~> 3.0"},
      {:ex_machina,
       [github: "thoughtbot/ex_machina", branch: "dependabot/hex/ecto-3.0.0", only: :test]},
      {:poison, "~> 4.0", override: true},
      {:httpoison, "~> 1.3"},
      {:libsodium, "~> 0.0.10"},
      {:binary, "~> 0.0.5"},
      {:ok, "~> 2.0"},
      {:plug, "~> 1.5"},
      {:ecto_sql, "~> 3.0-rc.1"},
      {:exw3, path: "../exw3"},
      {:keccakf1600, "~> 2.0.0", hex: :keccakf1600_orig},
      {:postgrex, "~> 0.14.0"},
      {:exth_crypto, "~> 0.1.4", override: true},
      {:mana, [github: "mana-ethereum/mana", app: false]},
      {:ethereumex,
       [github: "masonforest/ethereumex", branch: "websocket-client", override: true]},
      {:redix, "0.6.0"},
      {:remix, "~> 0.0.1", only: :dev},
      {:redix_pubsub, "~> 0.4.2"},
      # Pull down [this branch](https://github.com/cristianberneanu/rustler)
      # Until [this PR](https://github.com/hansihe/rustler/pull/166) is merged
      {:rustler, [path: "../rustler/rustler_mix", override: true]},
      {:sha3, "2.0.0"}
    ]
  end
end
