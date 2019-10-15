import Config
config :logger, level: :info
config :ellipticoind, ecto_repos: [Ellipticoind.Repo]
config :ellipticoind, p2p_transport: P2P.Transport.Libp2p

config :ellipticoind, P2P.Transport.Libp2p,
  ip: System.get_env("IP") || "localhost",
  port: if(System.get_env("PORT"), do: System.get_env("PORT") |> String.to_integer(), else: 4461),
  bootnodes: [
    "/ip4/157.230.9.137/tcp/4461/p2p/16Uiu2HAmPMs87kLhVA3UBvfxMeWFqhfVGQskGNbvT4VwrQiJ49Wx",
    "/ip4/134.209.218.26/tcp/4461/p2p/16Uiu2HAkwM7fpsBLsk8etXKrTHMAqqB1RcbFMsVTN5xdq2veJJPD",
    "/ip4/134.209.216.179/tcp/4461/p2p/16Uiu2HAm5mK7J9rqduo8v8LgVUbuAudeD2ehJjmC6Nba7Xya6FTN"

	]

config :ellipticoind, Ellipticoind.Repo,
  username: System.get_env("DATABASE_USER") || "ellipticoin",
  database: "ellipticoind",
  password: "",
  socket_dir: "/var/run/postgresql",
  pool_size: 15,
  loggers: []
