defmodule Models.Block do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 1, from: 2]

  schema "blocks" do
    field(:parent_block, :binary)
    field(:number, :integer)
    field(:total_burned, :integer)
    field(:winner, :binary)
    field(:state_changes_hash, :binary)
    timestamps
  end

  def max_burned(query \\ __MODULE__), do: from(q in query, order_by: q.total_burned)

  def latest(query \\ __MODULE__, count), do: from(q in query, order_by: q.number, limit: ^count)

  def changeset(user, params \\ %{}) do
    user
    |> cast(params, [:name, :email, :age])
    |> validate_required([
      :number,
      :parent_block,
      :state_changes_hash,
      :winner
    ])
  end

  def hash(block), do: Crypto.hash(to_binary(block))

  def forge() do
    TransactionProccessor.proccess_transactions(1)
  end

  defp to_binary(%{
         parent_block: parent_block,
         number: number,
         winner: winner,
         state_changes_hash: state_changes_hash
       }) do
    parent_block <> <<number::size(256)>> <> winner <> state_changes_hash
  end
end
