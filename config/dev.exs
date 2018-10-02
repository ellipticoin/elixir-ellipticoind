use Mix.Config
config :blacksmith, base_contracts_path: "./base_contracts"
config :blacksmith, port: 4047

config :blacksmith, Blacksmith.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "test_mix",
  username: "masonf",
  password: "",
  hostname: "localhost"
