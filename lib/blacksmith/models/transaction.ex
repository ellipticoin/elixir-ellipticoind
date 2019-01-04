defmodule Blacksmith.Models.Transaction do
  use Ecto.Schema
  alias Blacksmith.Repo
  alias Blacksmith.Models.Contract
  import Ecto.Changeset

  schema "transactions" do
    field(:block_id, :id)
    field(:contract_id, :id)
    field(:function, :string)
    field(:arguments, :binary)
    field(:sender, :binary)
    field(:nonce, :integer)

    timestamps()
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:arguments])
    |> validate_required([:arguments])
  end

  def post(params) do
    # contract =
    #   Repo.get_by(
    #     Contract,
    #     name: Atom.to_string(params.contract_name),
    #     address: params.address
    #   )
    #
    # %__MODULE__{
    #   contract_id: contract.id,
    #   function: Atom.to_string(params.function),
    #   arguments: Cbor.encode(params.arguments),
    #   sender: params.sender,
    #   nonce: params.nonce
    # }
    # |> Repo.insert!()
    TransactionPool.add(%{
      code: Contract.base_contract_code(params.contract_name),
      sender: params.sender,
      contract_address: <<0::256>>,
      contract_name: params.contract_name,
      function: params.function,
      arguments: params.arguments,
    })
  end
end
