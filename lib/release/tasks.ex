defmodule Release.Tasks do
  def migrate do
    {:ok, _} = Application.ensure_all_started(:node)

    path = Application.app_dir(:node, ["priv", "repo", "migrations"])

    Ecto.Migrator.run(Node.Repo, path, :up, all: true)
  end
end
