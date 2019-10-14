use Mix.Config
config :logger, level: :warn
config :bypass, adapter: Plug.Adapters.Cowboy2
config :ellipticoind, base_contracts_path: "./priv/base_contracts"
config :ellipticoind, port: 4047
config :ellipticoind, transaction_processing_time: 1000
config :ellipticoind, hashfactor_target: 1
config :ellipticoind, enable_miner: false
config :ellipticoind, https: false
config :ellipticoind, p2p_transport: P2P.Transport.Test

config :ellipticoind, ellipticoin_client: Test.MockEllipticoinClient
config :ellipticoind, client_timeout: 300_000
config :ellipticoind, P2P.Transport.Test,
  port: 4045,
  bootnodes:
    File.read!("./priv/bootnodes.txt")
    |> String.split("\n", trim: true)

config :ellipticoind, ellipticoind_url: "http://localhost:4047/"
config :ellipticoind, :redis_url, "redis://127.0.0.1:6379/"
config :ellipticoind, :rocksdb_path, "./var/storage"
config :ellipticoind, bootnodes: ["http://localhost:4047/"]

config :ellipticoind, Ellipticoind.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  username: "postgres",
  password: "",
  database: "ellipticoin_test",
  hostname: "localhost",
  pool_size: 10,
  log: false
