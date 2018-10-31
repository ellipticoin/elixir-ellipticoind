defmodule Models.Block do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  alias Blacksmith.Repo

  schema "blocks" do
    # belongs_to :parent, Block
    field(:number, :integer)
    # field(:total_burned, :integer)
    # field(:winner, :binary)
    # field(:state_changes_hash, :binary)
    timestamps()
  end

  def max_burned(query \\ __MODULE__), do: from(q in query, order_by: q.total_burned)

  def latest(query \\ __MODULE__, count), do: from(q in query, order_by: q.number, limit: ^count)

  def changeset(user, params \\ %{}) do
    user
    |> cast(params, [:number])
    |> validate_required([
      :number,
      # :state_changes_hash,
      # :winner
    ])
  end

  # def hash(block), do: Crypto.hash(to_binary(block))

  def forge() do
    TransactionProccessor.proccess_transactions(1)
    TransactionProccessor.wait_until_done()
    block = %__MODULE__{number: 0}
    IO.inspect block
    Repo.insert(block)
    block
  end

  # defp to_binary(%{
  #        number: number,
  #        winner: winner,
  #        state_changes_hash: state_changes_hash
  #      }) do
  #   <<number::size(256)>> <> winner <> state_changes_hash
  # end
end
