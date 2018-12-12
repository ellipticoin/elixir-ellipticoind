use Mix.Config

config :blacksmith, :ethereum_private_key, "wss://rinkeby.infura.io/ws"
config :blacksmith, base_contracts_path: "./base_contracts"
config :blacksmith, port: 4045
config :blacksmith, https: false
config :blacksmith, keyfile: "priv/ssl/privkey.pem"
config :blacksmith, certfile: "priv/ssl/fullchain.pem"
config :blacksmith, dhfile: "priv/ssl/ssl-dhparams.pem"

config :blacksmith, bootnode: false

config :blacksmith,
  staking_contract_address:
    "756d0ABF6235AB135126fe772CDaE195C3DECc0e" |> Base.decode16!(case: :mixed)

config :ethereumex, :web3_url, "wss://rinkeby.infura.io/ws"
config :ethereumex, :client_type, :websocket
config :blacksmith, ethereum_private_key: "1274EA29DC71B4B2E6439FDD109545E8C1585E2B16BCD45236FE20FBF919A70D" |> Base.decode16!()

config :blacksmith, :redis_url, "redis://localhost:6379/"
config :blacksmith, Blacksmith.Repo,
  username: "postgres",
  password: "",
  database: "blacksmith",
  hostname: "localhost",
  pool_size: 15
