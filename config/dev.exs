use Mix.Config

config :node, transaction_processing_time: 1000
config :node, mining_target_time: 1
config :node, enable_miner: true
config :node, node_url: "http://localhost:4047/"
config :node, base_contracts_path: "./priv/base_contracts"
config :node, port: 0
config :node, dhfile: nil
config :node, https: false
config :node, p2p_transport: P2P.Transport.Noise

config :node, P2P.Transport.Noise,
  private_key:
    "FbJ84KTznL4ME5InsxJalt5Asv5tVTRJwGnkZTMXMLe9Ayfcm9LcBMhO15D6A5h+5VKfZu64Af7h7w1j8K+3AA=="
    |> Base.decode64!(),
  port: if(System.get_env("PORT"), do: System.get_env("PORT") |> String.to_integer(), else: 4047),
  # File.read!("./priv/bootnodes.txt")
  bootnodes: if(System.get_env("BOOTNODES"), do: System.get_env("BOOTNODES"), else: "")
    |> String.split(",", trim: true)
  # bootnodes: []
  #


config :node, bootnode: true

# config :node, :redis_url, "redis://127.0.0.1:6379/"
config :node, :redis_url, System.get_env("REDIS_URL") || "redis://127.0.0.1:6379/"

config :node, Node.Repo,
  username: "masonf",
  password: "",
  database: System.get_env("DATABASE") || "ellipticoin",
  hostname: "localhost",
  pool_size: 10,
  log: false
