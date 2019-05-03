defmodule Release.Tasks do
  def migrate do
    {:ok, _} = Application.ensure_all_started(:ellipticoind)

    path = Application.app_dir(:ellipticoind, ["priv", "repo", "migrations"])

    Ecto.Migrator.run(Ellipticoind.Repo, path, :up, all: true)
  end
end
