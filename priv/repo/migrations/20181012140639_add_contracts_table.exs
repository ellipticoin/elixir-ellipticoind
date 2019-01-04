defmodule Blacksmith.Repo.Migrations.AddContractsTable do
  use Ecto.Migration

  def change do
    create table("contracts") do
      add :address, :binary
      add :code,    :binary
      add :name,    :varchar

      timestamps()
    end

    create unique_index(:contracts, [:address, :name])
  end
end
