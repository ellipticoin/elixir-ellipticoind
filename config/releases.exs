import Config
config :logger, level: :info
config :ellipticoind, ecto_repos: [Ellipticoind.Repo]
config :ellipticoind, p2p_transport: P2P.Transport.Noise

config :ellipticoind, P2P.Transport.Noise,
  hostname: System.get_env("HOSTNAME") || "localhost",
  private_key:
    "FbJ84KTznL4ME5InsxJalt5Asv5tVTRJwGnkZTMXMLe9Ayfcm9LcBMhO15D6A5h+5VKfZu64Af7h7w1j8K+3AA=="
    |> Base.decode64!(),
  port: if(System.get_env("PORT"), do: System.get_env("PORT") |> String.to_integer(), else: 4461),
  bootnodes:
    File.read!("./priv/bootnodes.txt")
    |> String.split("\n", trim: true)

config :ellipticoind, Ellipticoind.Repo,
  username: System.get_env("DATABASE_USER") || "ellipticoin",
  database: "ellipticoind",
  password: "",
  socket_dir: "/var/run/postgresql",
  pool_size: 15,
  loggers: []
