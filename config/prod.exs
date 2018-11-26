use Mix.Config

private_key =
  <<238, 163, 60, 8, 21, 24, 67, 133, 67, 178, 163, 66, 57, 255, 25, 13, 1, 184, 12, 138, 211,
    125, 187, 121, 14, 43, 17, 237, 131, 168, 205, 133>>

config :blacksmith, base_contracts_path: "./base_contracts"
config :blacksmith, port: 4047
config :blacksmith, private_key: private_key

config :blacksmith,
  staking_contract_address:
    "756d0ABF6235AB135126fe772CDaE195C3DECc0e" |> Base.decode16!(case: :mixed)

# config :ex_wire, private_key, private_key
# private_key:
#   <<18, 116, 234, 41, 220, 113, 180, 178, 230, 67, 159, 221, 16, 149, 69, 232, 193, 88, 94, 43,
# 22, 188, 212, 82, 54, 254, 32, 251, 249, 25, 167, 13>>
config :ethereumex, :web3_url, "wss://ropsten.infura.io/ws/v3/28d900c929bf4df88e0a4adc9f790e22"
# config :ethereumex, :client_type, :websocket

config :blacksmith, Blacksmith.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "test_mix",
  username: "masonf",
  password: "",
  hostname: "localhost"
