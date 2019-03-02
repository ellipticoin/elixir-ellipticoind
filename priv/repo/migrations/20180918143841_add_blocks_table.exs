defmodule Node.Repo.Migrations.AddBlocksTable do
  use Ecto.Migration

  def change do
    create table("blocks", primary_key: false) do
      add :block_hash, :binary, private_key: true
      add :number, :integer
      add :total_burned, :integer
      add :winner, :binary
      add :changeset_hash, :binary
      add :proof_of_work_value, :integer

      timestamps()
    end

    create unique_index(:blocks, [:block_hash])

    alter table("blocks", primary_key: false) do
      add :parent_hash, references(:blocks, column: :block_hash, type: :binary)
    end
  end
end
