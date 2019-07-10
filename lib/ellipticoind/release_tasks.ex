defmodule Ellipticoind.ReleaseTasks do
  @repos Application.get_env(:ellipticoind, :ecto_repos, [])

  def generate_private_key() do
    IO.puts("New private_key:")

    IO.puts(
      Crypto.keypair()
      |> elem(1)
      |> Base.encode64()
    )
  end

  def migrate(_argv) do
    Application.ensure_all_started(:ellipticoind)
    Enum.each(@repos, &run_migrations_for/1)
  end

  defp run_migrations_for(repo) do
    app = Keyword.get(repo.config, :otp_app)
    IO.puts("Running migrations for #{app}")
    migrations_path = priv_path_for(repo, "migrations")
    Ecto.Migrator.run(repo, migrations_path, :up, all: true)
  end

  defp priv_path_for(repo, filename) do
    app = Keyword.get(repo.config, :otp_app)

    repo_underscore =
      repo
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    priv_dir = "#{:code.priv_dir(app)}"

    Path.join([priv_dir, repo_underscore, filename])
  end
end
