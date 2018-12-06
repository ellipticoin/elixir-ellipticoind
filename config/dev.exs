use Mix.Config

config :blacksmith, base_contracts_path: "./base_contracts"
config :blacksmith, port: 4047

config :blacksmith,
  staking_contract_address:
    "756d0ABF6235AB135126fe772CDaE195C3DECc0e" |> Base.decode16!(case: :mixed)

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
