defmodule Blacksmith.Repo.Migrations.AddContractsTable do
  use Ecto.Migration

  def change do
    create table("contracts") do
      add :code,    :binary
      add :name,    :binary

      timestamps()
    end
  end
end
