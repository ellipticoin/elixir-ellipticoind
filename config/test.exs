use Mix.Config
config :blacksmith, base_contracts_path: "./base_contracts"
config :blacksmith, port: 4047
config :blacksmith, Blacksmith.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "masonf",
  password: "",
  database: "test_phoenix_dev",
  hostname: "localhost",
  pool_size: 10
