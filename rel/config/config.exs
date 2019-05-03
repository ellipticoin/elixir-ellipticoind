use Mix.Config

config :logger, level: :info
config :ellipticoind, transaction_processing_time: 1000
config :ellipticoind, mining_target_time: 15000
config :ellipticoind, base_contracts_path: "lib/ellipticoind-0.1.0/priv/base_contracts/"
config :ellipticoind, port: 4460
config :ellipticoind, enable_miner: true
config :ellipticoind, private_key: "FbJ84KTznL4ME5InsxJalt5Asv5tVTRJwGnkZTMXMLe9Ayfcm9LcBMhO15D6A5h+5VKfZu64Af7h7w1j8K+3AA==" |> Base.decode64!()
config :ellipticoind, P2P.Transport.Noise,
  port: 4461,
  bootnodes:  File.read!("lib/ellipticoind-0.1.0/priv/bootnodes.txt")
   |> String.split("\n", trim: true)

config :ellipticoind, bootellipticoind: false
config :ellipticoind, :redis_url, "redis://localhost:6379/"
config :ellipticoind, Ellipticoind.Repo,
  username: "ellipticoin",
  password: "",
  database: "ellipticoin",
  socket_dir: "/var/run/postgresql",
  pool_size: 15,
  loggers: []
