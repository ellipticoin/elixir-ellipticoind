use Mix.Config
config :node, ecto_repos: [Node.Repo]
config :node, p2p_transport: P2P.Transport.Noise
import_config "#{Mix.env()}.exs"
import_config "#{Mix.env()}.secret.exs"
