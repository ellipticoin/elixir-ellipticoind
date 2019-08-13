defmodule Ellipticoind.Views.TransactionView do
  alias Ellipticoind.Models.Transaction

  def as_map(transaction) do
    transaction
    |> Map.take(Transaction.__schema__(:fields))
    |> Map.drop([
      :block_hash,
      :signature,
      :id
    ])
  end

  def as_map_with_hash(transaction) do
    if Map.has_key?(transaction, :hash) do
      as_map(transaction)
    else
      as_map(transaction)
      |> Map.put(:hash, Map.get(transaction, :hash))
    end
  end
end
