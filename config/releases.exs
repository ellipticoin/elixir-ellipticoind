import Config
config :logger, level: :info
config :ellipticoind, ecto_repos: [Ellipticoind.Repo]
config :ellipticoind, p2p_transport: P2P.Transport.Libp2p
config :ellipticoind, client_timeout: 300_000
config :ellipticoind, ellipticoin_client: EllipticoinClient
config :ellipticoind, P2P.Transport.Libp2p,
  ip: System.get_env("IP") || "localhost",
  port: if(System.get_env("PORT"), do: System.get_env("PORT") |> String.to_integer(), else: 4461)

config :ellipticoind, Ellipticoind.Repo,
  username: System.get_env("DATABASE_USER") || "ellipticoin",
  database: "ellipticoind",
  password: "",
  socket_dir: "/var/run/postgresql",
  pool_size: 15,
  loggers: []
