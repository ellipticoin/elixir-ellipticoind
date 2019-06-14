defmodule Ellipticoind.Models.Transaction do
  use Ecto.Schema
  alias Ellipticoind.Models.Contract
  alias Ellipticoind.Ecto.Types
  alias Ellipticoind.Repo
  import Ecto.Changeset

  schema "transactions" do
    field(:block_hash, :binary)
    field(:contract_name, Types.Atom)
    field(:contract_address, :binary)
    field(:function, Types.Atom)
    field(:arguments, Types.Cbor)
    field(:sender, :binary)
    field(:nonce, :integer)
    field(:return_code, :integer)
    field(:return_value, Types.Cbor)
    field(:signature, :binary)
    field(:execution_order, :integer)

    timestamps()
  end

  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :sender,
      :nonce,
      :block_hash,
      :contract_address,
      :contract_name,
      :return_code,
      :return_value,
      :function,
      :arguments,
      :execution_order
    ])
    |> validate_required([
      :contract_address,
      :contract_name,
      :return_code,
      :function,
      :arguments,
      :execution_order
    ])
  end

  def as_map(attributes) do
    attributes
    |> Map.take([
      :nonce,
      :block_hash,
      :sender,
      :function,
      :contract_name,
      :contract_address,
      :arguments,
      :return_value,
      :return_code,
      :execution_order
    ])
  end

  def with_code(attributes) do
    code =
      Repo.get_by(Contract, name: attributes.contract_name)
      |> Map.get(:code)

    attributes
    |> Map.merge(%{
      contract_address: <<0::256>>,
      code: code
    })
    |> Map.drop([
      :return_code,
      :return_value
    ])
  end

  def sign(transaction, private_key) do
    sender = Crypto.private_key_to_public_key(private_key)
    transaction = transaction
    |> Map.put(:sender, sender)

    signature = Crypto.sign(as_map(transaction), private_key)

    transaction
    |> Map.put(:signature, signature)
  end

  def from_signed_transaction(signed_transaction) do
    {signature, transaction} = Map.pop(signed_transaction, :signature)
    if Crypto.valid_signature?(signature, as_binary(transaction), signed_transaction.sender) do
      {:ok, transaction}
    else
      {:error, :invalid_signature}
    end

  end

  def post(parameters) do
    transaction_bytes =
      parameters
      |> Cbor.encode()

    Redis.push("transactions::queued", [transaction_bytes])
  end

  def as_binary(transaction),
    do:
      as_map(transaction)
      |> Cbor.encode()
end
