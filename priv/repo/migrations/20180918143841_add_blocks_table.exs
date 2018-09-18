defmodule Blacksmith.Repo.Migrations.AddBlocksTable do
  use Ecto.Migration

  def change do
    create table("blocks") do
      add :parent_block, :binary
      add :number, :integer
      add :total_difficulty, :integer
      add :winner, :binary
      add :state_changes_hash, :binary

      timestamps()
    end
  end
end
