defmodule Ellipticoind.Models.Block do
  use Ecto.Schema
  require Logger
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  alias Ellipticoind.{Repo, Miner}
  alias Ellipticoind.Models.Transaction
  alias Ellipticoind.Views.BlockView
  alias Ellipticoind.Models.Block.Validations
  alias Ellipticoind.{TransactionProcessor, Storage, Memory}

  @primary_key false
  schema "blocks" do
    field(:hash, :binary, default: <<0::256>>, primary_key: true)

    belongs_to(:parent, __MODULE__,
      source: :parent_hash,
      foreign_key: :hash,
      references: :hash,
      type: :binary,
      define_field: false
    )

    has_many(:transactions, Transaction, references: :hash, foreign_key: :block_hash)
    field(:number, :integer, default: 0)
    field(:total_burned, :integer, default: 0)
    field(:winner, :binary, default: <<0::256>>)
    field(:memory_changeset_hash, :binary, default: Crypto.hash(<<>>))
    field(:storage_changeset_hash, :binary, default: Crypto.hash(<<>>))
    field(:proof_of_work_value, :integer)
  end

  def build_next(attributes) do
    case best() do
      nil ->
        %{}

      best_block ->
        %{
          number: best_block.number + 1,
          parent_hash: best_block.hash
        }
    end
    |> Map.merge(%{
      winner: Configuration.public_key()
    })
    |> Map.merge(attributes)
  end

  def as_binary(block) do
    Cbor.encode(BlockView.as_map(block))
  end

  def next_block_number(),
    do:
      (case(best()) do
         nil -> 0
         best -> best.number + 1
       end)

  def best(query \\ __MODULE__),
    do:
      from(q in query, order_by: [desc: q.number])
      |> Ecto.Query.first()
      |> Repo.one()

  def latest(query \\ __MODULE__, count),
    do: from(q in query, order_by: [desc: q.number], limit: ^count)

  def changeset(block, params \\ %{}) do
    block_hash = Crypto.hash(params)
    params = Map.put(params, :hash, block_hash)

    block
    |> cast(params, [
      :hash,
      :number,
      :memory_changeset_hash,
      :storage_changeset_hash,
      :proof_of_work_value,
      :winner
    ])
    |> unique_constraint(:hash)
    |> cast_assoc(:transactions)
    |> validate_required([
      :hash,
      :memory_changeset_hash,
      :storage_changeset_hash,
      :number,
      :proof_of_work_value,
      :winner
    ])
  end
end
