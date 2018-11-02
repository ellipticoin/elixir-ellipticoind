use Mix.Config
config :blacksmith, base_contracts_path: "./base_contracts"
config :blacksmith, port: 4047

config :blacksmith,
  staking_contract_address:
    "9cEe17E3614aAd1CacF3E003c83350ad6fd761C6" |> Base.decode16!(case: :mixed)

config :blacksmith, auto_forge: true

config :ex_wire,
  private_key:
    <<18, 116, 234, 41, 220, 113, 180, 178, 230, 67, 159, 221, 16, 149, 69, 232, 193, 88, 94, 43,
      22, 188, 212, 82, 54, 254, 32, 251, 249, 25, 167, 13>>

config :ethereumex, :web3_url, "wss://rinkeby.infura.io/ws"
config :ethereumex, :client_type, :websocket

config :blacksmith, Blacksmith.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  username: "masonf",
  password: "",
  database: "test_phoenix_dev",
  hostname: "localhost",
  pool_size: 10,
  log: false
