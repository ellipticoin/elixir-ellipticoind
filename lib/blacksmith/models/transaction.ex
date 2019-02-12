defmodule Blacksmith.Models.Transaction do
  use Ecto.Schema
  alias Blacksmith.Repo
  alias Blacksmith.Models.{Contract, Block}
  alias Blacksmith.Ecto.Types
  import Ecto.Changeset

  schema "transactions" do
    belongs_to(:block, Block)
    belongs_to(:contract, Contract)
    field(:function, Types.Atom)
    field(:arguments, Types.Cbor)
    field(:sender, :binary)
    field(:nonce, :integer)
    field(:return_code, :integer)
    field(:return_value, Types.Cbor)
    field(:signature, :binary)

    timestamps()
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :block_id,
      :contract_id,
      :return_code,
      :return_value,
      :arguments
    ])
    |> validate_required([:arguments])
  end

  def as_map(%{
        sender: sender,
        nonce: nonce,
        contract: contract,
        function: function,
        arguments: arguments,
        signature: signature
      }) do
    %{
      sender: sender,
      nonce: nonce,
      contract_address: contract.address,
      contract_name: contract.name,
      function: function,
      arguments: arguments,
      signature: signature
    }
  end

  def new(options \\ [], private_key) do
    sender = Crypto.public_key_from_private_key(private_key)

    transaction =
      options
      |> Map.put(:sender, sender)

    signature = Crypto.sign(transaction, private_key)
    {contract_address, options} = Map.pop(options, :contract_address)
    {contract_name, _options} = Map.pop(options, :contract_name)

    contract =
      Repo.get_by(Contract, %{
        address: contract_address || <<0::256>>,
        name: contract_name || :BaseToken
      })

    transaction =
      transaction
      |> Map.put(:signature, signature)
      |> Map.put(:contract, contract)

    struct(__MODULE__, transaction)
  end

  def post(params) do
    TransactionPool.add(%{
      code: Contract.base_contract_code(params.contract_name),
      sender: params.sender,
      contract_address: <<0::256>>,
      contract_name: params.contract_name,
      function: params.function,
      arguments: params.arguments
    })
  end
end
