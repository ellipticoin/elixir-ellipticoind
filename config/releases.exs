import Config
config :logger, level: :info
config :ellipticoind, ecto_repos: [Ellipticoind.Repo]
config :ellipticoind, p2p_transport: P2P.Transport.Noise
config :ellipticoind, Ellipticoind.Repo,
  username: System.get_env("DATABASE_USER") || "ellipticoin",
  password: System.get_env("DATABASE_PASS") || "",
  database: "ellipticoind",
  hostname: System.get_env("DATABASE_HOST") || "localhost",
  pool_size: 15,
  loggers: []
