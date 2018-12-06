use Mix.Config

config :blacksmith, base_contracts_path: "./base_contracts"
config :blacksmith, port: String.to_integer(System.get_env("PORT") || "4045")

config :blacksmith,
  staking_contract_address:
    (System.get_env("STAKING_CONTRACT_ADDRESS") || "") |> Base.decode16!(case: :mixed)

config :ethereumex, :web3_url, System.get_env("WEB3_URL")
config :ethereumex, :client_type, :websocket
config :blacksmith, private_key: (System.get_env("ETHEREUM_PRIVATE_KEY") || "") |> Base.decode16!()

config :blacksmith, :redis_url, System.get_env("REDIS_URL")
config :blacksmith, Blacksmith.Repo,
  username: System.get_env("POSTGRES_USER"),
  password: System.get_env("POSTGRES_PASS"),
  database: System.get_env("POSTGRES_DB"),
  hostname: System.get_env("POSTGRES_HOST"),
  pool_size: 15
