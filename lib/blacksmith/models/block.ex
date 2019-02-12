defmodule Blacksmith.Models.Block do
  @transaction_processing_time 1
  use Ecto.Schema
  require Logger
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  alias Blacksmith.Repo
  alias Blacksmith.Models.{Contract, Transaction}
  alias Ethereum.Contracts.EllipticoinStakingContract
  alias Crypto.RSA

  schema "blocks" do
    belongs_to(:parent, __MODULE__)
    has_many(:transactions, Transaction)
    field(:number, :integer)
    field(:total_burned, :integer)
    field(:winner, :binary)
    field(:changeset_hash, :binary)
    field(:block_hash, :binary)
    timestamps()
  end

  def best_block(query \\ __MODULE__),
    do:
      from(q in query, order_by: q.total_burned)
      |> Ecto.Query.first()

  def latest(query \\ __MODULE__, count),
    do: from(q in query, order_by: [desc: q.number], limit: ^count)

  def log(message, block) do
    Logger.info(
      "#{message}: " <>
        "Number=#{block.number} " <> "Winner=#{Ethereum.Helpers.bytes_to_hex(block.winner)}"
    )
  end

  def changeset(user, params \\ %{}) do
    user
    |> cast(params, [:number])
    |> validate_required([
      :number,
      :changeset_hash,
      :block_hash,
      :winner
    ])
  end

  def hash(block), do: Crypto.hash(to_binary(block))

  def as_map(%{
        parent: parent,
        number: number,
        block_hash: block_hash,
        total_burned: total_burned,
        winner: winner,
        transactions: transactions,
        changeset_hash: changeset_hash
      }),
      do: %{
        parent_hash:
          if(Ecto.assoc_loaded?(parent), do: parent.block_hash || <<0::256>>, else: <<0::256>>),
        block_hash: block_hash,
        total_burned: total_burned || 0,
        number: number,
        winner: winner,
        changeset_hash: changeset_hash,
        transactions:
          if(Ecto.assoc_loaded?(transactions),
            do: Enum.map(transactions, &Transaction.as_map/1),
            else: []
          )
      }

  def apply(%{winner: winner, number: number, transactions: transactions}) do
    {:ok, block} =
      insert(%{
        winner: winner,
        number: number
      })

    if !Enum.empty?(transactions) do
      Enum.map(transactions, fn transaction ->
        contract_name = Map.get(transaction, :contract_name)
        code = Contract.base_contract_code(contract_name)

        Map.put(transaction, :code, code)
        |> Map.delete(:signature)
      end)
        |> TransactionProcessor.proccess_block()

      insert_done_transactions(block)
    end

    log("Applied Block", block)

    {:ok, block}
  end

  def forge() do
    TransactionProcessor.proccess_transactions(@transaction_processing_time)

    {:ok, block} =
      insert(%{
        winner: EllipticoinStakingContract.winner(),
        number: EllipticoinStakingContract.block_number() + 1
      })

    insert_done_transactions(block)
    P2P.broadcast_block(block)
    submit_block(block)
    WebsocketHandler.broadcast(:blocks, block)
    log("Forged Block", block)

    {:ok, block}
  end

  def insert(options) do
    {:ok, changeset} = Redis.fetch("changeset", <<>>)
    parent = best_block() |> Repo.one()
    Redis.delete("changeset")

    block =
      struct(
        __MODULE__,
        Map.merge(
          %{
            parent: parent,
            changeset_hash: Crypto.hash(changeset)
          },
          options
        )
      )

    block = Map.put(block, :block_hash, hash(block))
    Repo.insert(block)
  end

  def insert_done_transactions(block) do
    {:ok, transactions} = Redis.get_list("transactions::done")
    {:ok, results} = Redis.get_list("results")

    Enum.zip(transactions, results)
    |> Enum.map(fn {transaction_bytes, result_bytes} ->
      transaction = Cbor.decode!(transaction_bytes)

      {
        %{
          contract_address: contract_address,
          contract_name: contract_name
        },
        transaction
      } = Map.split(transaction, [:contract_name, :contract_address])

      contract =
        Repo.get_by(Contract, %{
          address: contract_address,
          name: contract_name
        })

      <<return_code::integer-size(32), return_value::binary>> = result_bytes

      transaction =
        Map.merge(
          transaction,
          %{
            contract_id: contract.id,
            block_id: block.id,
            return_code: return_code,
            return_value: Cbor.decode!(return_value)
          }
        )

      Transaction.changeset(%Transaction{}, transaction)
      |> Repo.insert!()
    end)
  end

  defp submit_block(block) do
    block_hash = block.block_hash
    block_number = block.number
    last_signature = EllipticoinStakingContract.last_signature()

    rsa_key =
      Application.get_env(:blacksmith, :private_key)
      |> RSA.parse_pem()

    signature = RSA.sign(last_signature, rsa_key)

    EllipticoinStakingContract.submit_block(block_number, block_hash, signature)
  end

  defp to_binary(%{
         number: number,
         winner: winner,
         changeset_hash: changeset_hash
       }) do
    <<number::size(256)>> <> winner <> changeset_hash
  end

  def as_cbor(block), do: Cbor.encode(as_map(block))
end
