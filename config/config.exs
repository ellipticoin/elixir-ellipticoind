use Mix.Config
config :ellipticoind, ecto_repos: [Ellipticoind.Repo]
config :ellipticoind, p2p_transport: P2P.Transport.Noise
import_config "#{Mix.env()}.exs"
import_config "#{Mix.env()}.secret.exs"
