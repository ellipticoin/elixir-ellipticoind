use Mix.Config
config :logger, level: :warn
config :bypass, adapter: Plug.Adapters.Cowboy2
config :node, base_contracts_path: "./priv/base_contracts"
config :node, port: 4047
config :node, transaction_processing_time: 1000
config :node, mining_target_time: 1
config :node, enable_miner: false
config :node, bootnode: true
config :node, https: false
config :node, private_key: File.read!("./config/private_key.pem")
config :node, p2p_transport: P2P.Transport.Test

config :node, P2P.Transport.Test,
  private_key: File.read!("./config/private_key.pem"),
  port: 4045,
  bootnodes:
    File.read!("./priv/bootnodes.txt")
    |> String.split("\n", trim: true)

config :node, node_url: "http://localhost:4047/"
config :node, :redis_url, "redis://127.0.0.1:6379/"
config :node, bootnodes: ["http://localhost:4047/"]

config :node, Node.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  username: "masonf",
  password: "",
  database: "blacksmith_test",
  hostname: "localhost",
  pool_size: 10,
  log: false
