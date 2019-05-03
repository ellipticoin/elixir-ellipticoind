defmodule Ellipticoind.Repo.Migrations.AddContractsTable do
  use Ecto.Migration

  def change do
    create table("contracts") do
      add :address, :binary
      add :name,    :varchar
      add :code,    :binary

      timestamps()
    end

    create unique_index(:contracts, [:address, :name])
  end
end
