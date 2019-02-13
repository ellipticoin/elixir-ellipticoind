use Mix.Config

config :blacksmith, node_url: "http://localhost:4047/"
config :blacksmith, base_contracts_path: "./base_contracts"
config :blacksmith, port: 4047
config :blacksmith, https: false
config :blacksmith, keyfile: "priv/ssl/privkey.pem"
config :blacksmith, certfile: "priv/ssl/fullchain.pem"
config :blacksmith, dhfile: "priv/ssl/ssl-dhparams.pem"

config :blacksmith, bootnode: true

config :blacksmith,
  bootnodes:
    Path.join([Path.dirname(__DIR__), "priv", "bootnodes.txt"])
    |> File.read!()
    |> String.split("\n")

config :blacksmith,
  staking_contract_address: "0x8141b366d4af1fe6752F1eeD3F2918559f1cb295"

config :ethereumex, :client_type, :websocket
config :ethereumex, :web3_url, "wss://rinkeby.infura.io/ws/v3/28d900c929bf4df88e0a4adc9f790e22"
config :blacksmith, :redis_url, "redis://127.0.0.1:6379/"

config :blacksmith, Blacksmith.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "blacksmith_dev",
  username: "masonf",
  password: "",
  hostname: "localhost",
  log: false
