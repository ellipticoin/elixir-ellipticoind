defmodule Node.Models.Block do
  use Ecto.Schema
  require Logger
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  alias Node.Repo
  alias Node.Models.Transaction
  alias Node.Models.Block.Validations

  @primary_key false
  schema "blocks" do
    field(:hash, :binary, default: <<0::256>>, primary_key: true)

    belongs_to(:parent, __MODULE__,
      source: :parent_hash,
      foreign_key: :hash,
      type: :binary,
      define_field: false
    )

    has_many(:transactions, Transaction, references: :hash, foreign_key: :block_hash)
    field(:number, :integer, default: 0)
    field(:total_burned, :integer, default: 0)
    field(:winner, :binary, default: <<0::256>>)
    field(:changeset_hash, :binary, default: Crypto.hash(<<>>))
    field(:proof_of_work_value, :integer)
    timestamps()
  end

  def next_block_params() do
    best_block = best() |> Repo.one()

    if best_block do
      %{
        number: best_block.number + 1,
        parent: best_block
      }
    else
      %{
        number: 0
      }
    end
    |> Map.merge(%{
      winner: Config.public_key()
    })
  end

  def best(query \\ __MODULE__),
    do:
      from(q in query, order_by: [desc: q.number])
      |> Ecto.Query.first()

  def latest(query \\ __MODULE__, count),
    do: from(q in query, order_by: [desc: q.number], limit: ^count)

  def log(message, block) do
    Logger.info(
      "#{message}: " <>
        "Number=#{block.number}"
    )
  end

  def changeset(user, params \\ %{}) do
    params = set_hash(params)

    params = %{
      params
      | transactions:
          Enum.map(params.transactions, fn transaction ->
            Map.put(transaction, :block_hash, hash(params))
          end)
    }

    user
    |> cast(params, [
      :hash,
      :number,
      :changeset_hash,
      :proof_of_work_value,
      :winner
    ])
    |> cast_assoc(:transactions)
    |> validate_required([
      :hash,
      :changeset_hash,
      :number,
      :proof_of_work_value,
      :winner
    ])
  end

  def set_hash(attrs) do
    Map.put(attrs, :hash, hash(attrs))
  end

  def hash(block), do: Crypto.hash(as_binary(block))

  def as_map(attributes) do
    Map.take(attributes, [
      :hash,
      :proof_of_work_value,
      :total_burned,
      :changeset_hash,
      :number,
      :winner
    ])
    |> Map.put(
      :transactions,
      transactions_as_map(attributes.transactions)
    )
    |> Map.put(
      :parent_hash,
      if(Map.has_key?(attributes, :parent) && Ecto.assoc_loaded?(attributes.parent),
        do: attributes.parent.hash,
        else: nil
      )
    )
  end

  def transactions_as_map(transactions),
    do:
      if(Ecto.assoc_loaded?(transactions),
        do: Enum.map(transactions, &Transaction.as_map/1),
        else: []
      )

  def apply(block) do
    if Validations.valid_next_block?(block) do
      block
        |> TransactionProcessor.process()
        |> case do
          {:ok, _} ->
            insert(block)
          _ ->
            nil
      end
    end
  end

  def insert(attributes) do
    block =
      changeset(%__MODULE__{}, attributes)
      |> Repo.insert!()

    WebsocketHandler.broadcast(:blocks, block)
    block
  end

  def as_binary(block),
    do:
      as_map(block)
      |> Cbor.encode()

  def as_binary_pre_pow(block),
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
      |> Cbor.encode()

  def from_binary(bytes) do
    params = Cbor.decode!(bytes)

    struct(__MODULE__, params)
  end
end
