defmodule Ellipticoind.Views.BlockView do
  alias Ellipticoind.Repo
  alias Ellipticoind.Models.Block
  alias Ellipticoind.Views.TransactionView

  def as_map(block) do
    block
    |> Repo.preload(:parent)
    |> Map.take(Block.__schema__(:fields) ++ [:transactions])
    |> Map.update(:transactions, [], fn transactions ->
      if Ecto.assoc_loaded?(transactions) do
        Enum.map(transactions, &TransactionView.as_map/1)
      else
        []
      end
    end)
    |> Map.put(:parent_hash, if(Ecto.assoc_loaded?(block.parent), do: block.parent.hash))
  end

  def as_map_pre_pow(block),
    do:
      block
      |> as_map()
      |> Map.drop([
        :proof_of_work_value,
        :parent_hash,
        :parent,
        :hash,
        :total_burned
      ])
      |> Map.update!(:transactions, fn transactions ->
        Enum.map(transactions, fn transaction ->
          Map.drop(transaction, [
            :block_hash,
            :hash,
            :signature,
            :id
          ])
        end)
      end)
end
