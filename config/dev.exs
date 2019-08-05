use Mix.Config

config :ellipticoind, transaction_processing_time: 1
config :ellipticoind, hashfactor_target: 500_000
config :ellipticoind, enable_miner: true
config :ellipticoind, ellipticoind_url: "http://localhost:4047/"
config :ellipticoind, base_contracts_path: "./priv/base_contracts"
config :ellipticoind, :rocksdb_path, "./var/storage"

config :ellipticoind,
  port:
    if(System.get_env("API_PORT"),
      do: System.get_env("API_PORT") |> String.to_integer(),
      else: 4460
    )

config :ellipticoind, dhfile: nil
config :ellipticoind, https: false
config :ellipticoind, p2p_transport: P2P.Transport.Noise

config :ellipticoind, P2P.Transport.Noise,
  private_key:
    "FbJ84KTznL4ME5InsxJalt5Asv5tVTRJwGnkZTMXMLe9Ayfcm9LcBMhO15D6A5h+5VKfZu64Af7h7w1j8K+3AA==",
  port: if(System.get_env("PORT"), do: System.get_env("PORT") |> String.to_integer(), else: 4047),
  # File.read!("./priv/bootnodes.txt")
  bootnodes:
    if(System.get_env("BOOTNODES"), do: System.get_env("BOOTNODES"), else: "")
    |> String.split(",", trim: true)

# bootnodes: []
#

config :ellipticoind, bootellipticoind: true

# config :ellipticoind, :redis_url, "redis://127.0.0.1:6379/"
config :ellipticoind, :redis_url, System.get_env("REDIS_URL") || "redis://127.0.0.1:6379/"
config :ellipticoind, :rocksdb_path, System.get_env("ROCKSDB_PATH") || "./var/storage"

config :ellipticoind, Ellipticoind.Repo,
  username: "masonf",
  password: "",
  database: System.get_env("DATABASE") || "ellipticoin",
  hostname: "localhost",
  pool_size: 10,
  log: false
