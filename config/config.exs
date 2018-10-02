use Mix.Config
config :blacksmith, ecto_repos: [Blacksmith.Repo]
import_config "#{Mix.env()}.exs"
