defmodule Ellipticoind.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :block_hash, references(:blocks, column: :hash, type: :binary)
      add :contract_address, :binary
      add :contract_name, :varchar
      add :sender, :binary
      add :nonce, :integer
      add :function, :varchar
      add :arguments, :binary
      add :return_code, :integer
      add :return_value, :binary
      add :signature, :binary

      timestamps()
    end

    create index(:transactions, [:block_hash])
    create index(:transactions, [:contract_name, :contract_address])
  end
end
