defmodule Blacksmith.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :nonce, :integer
      add :sender, :binary
      add :block_id, references(:blocks, on_delete: :nothing)
      add :function, :varchar
      add :arguments, :binary
      add :contract_id, references(:contracts, on_delete: :nothing)

      timestamps()
    end

    create index(:transactions, [:block_id])
    create index(:transactions, [:contract_id])
  end
end
