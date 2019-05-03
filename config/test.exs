use Mix.Config
config :logger, level: :warn
config :bypass, adapter: Plug.Adapters.Cowboy2
config :ellipticoind, base_contracts_path: "./priv/base_contracts"
config :ellipticoind, port: 4047
config :ellipticoind, transaction_processing_time: 1000
config :ellipticoind, mining_target_time: 1
config :ellipticoind, enable_miner: false
config :ellipticoind, bootellipticoind: true
config :ellipticoind, https: false
config :ellipticoind, private_key: File.read!("./config/private_key.pem")
config :ellipticoind, p2p_transport: P2P.Transport.Test

config :ellipticoind, P2P.Transport.Test,
  private_key: File.read!("./config/private_key.pem"),
  port: 4045,
  bootnodes:
    File.read!("./priv/bootnodes.txt")
    |> String.split("\n", trim: true)

config :ellipticoind, ellipticoind_url: "http://localhost:4047/"
config :ellipticoind, :redis_url, "redis://127.0.0.1:6379/"
config :ellipticoind, bootnodes: ["http://localhost:4047/"]

config :ellipticoind, Ellipticoind.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  username: "masonf",
  password: "",
  database: "blacksmith_test",
  hostname: "localhost",
  pool_size: 10,
  log: false
