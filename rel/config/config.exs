use Mix.Config

config :logger, level: :info
config :node, transaction_processing_time: 1000
config :node, mining_target_time: 1000
config :node, base_contracts_path: "./priv/base_contracts"
config :node, port: 4460
config :node, https: false
config :node, enable_miner: true
config :node, keyfile: "priv/ssl/privkey.pem"
config :node, certfile: "priv/ssl/fullchain.pem"
config :node, dhfile: "priv/ssl/ssl-dhparams.pem"
config :node, private_key: "FbJ84KTznL4ME5InsxJalt5Asv5tVTRJwGnkZTMXMLe9Ayfcm9LcBMhO15D6A5h+5VKfZu64Af7h7w1j8K+3AA==" |> Base.decode64!()
config :node, P2P.Transport.Noise,
  private_key: "FbJ84KTznL4ME5InsxJalt5Asv5tVTRJwGnkZTMXMLe9Ayfcm9LcBMhO15D6A5h+5VKfZu64Af7h7w1j8K+3AA==" |> Base.decode64!(),
  port: (if System.get_env("PORT"), do: System.get_env("PORT") |> String.to_integer(), else: 4047),
  bootnodes:  File.read!("lib/node-0.1.0/priv/bootnodes.txt")
   |> String.split("\n", trim: true)

config :node, bootnode: false
config :node, :redis_url, "redis://localhost:6379/"
config :node, Node.Repo,
  username: "masonf",
  password: "",
  database: "node",
  hostname: "localhost",
  pool_size: 15,
  loggers: []
