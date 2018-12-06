defmodule Release.Tasks do
  def migrate do
    {:ok, _} = Application.ensure_all_started(:blacksmith)

    path = Application.app_dir(:blacksmith, ["priv", "repo", "migrations"])

    Ecto.Migrator.run(Blacksmith.Repo, path, :up, all: true)
  end
end  
