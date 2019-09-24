defmodule Ellipticoind.Repo.Migrations.AddContractsTable do
  use Ecto.Migration

  def change do
    create table("contracts") do
      add :address, :binary
      add :code,    :binary

      timestamps()
    end
  end
end
