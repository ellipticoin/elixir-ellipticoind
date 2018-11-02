defmodule Blacksmith.Repo.Migrations.AddBlocksTable do
  use Ecto.Migration

  def change do
    create table("blocks") do
      add :parent_id, references(:blocks)
      add :number, :integer
      add :total_burned, :integer
      add :winner, :binary
      add :changeset_hash, :binary
      add :block_hash, :binary

      timestamps()
    end
  end
end
