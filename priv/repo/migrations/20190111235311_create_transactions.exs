defmodule Blacksmith.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :block_id, references(:blocks, on_delete: :nothing)
      add :contract_id, references(:contracts, on_delete: :nothing)
      add :sender, :binary
      add :nonce, :integer
      add :function, :varchar
      add :arguments, :binary
      add :return_code, :integer
      add :return_value, :binary
      add :signature, :binary

      timestamps()
    end

    create index(:transactions, [:block_id])
    create index(:transactions, [:contract_id])
  end
end
