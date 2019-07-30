defmodule Ellipticoind.Models.Transaction do
  use Ecto.Schema
  alias Ecto.Changeset
  alias Ellipticoind.Ecto.Types
  import Ecto.Changeset

  schema "transactions" do
    field(:hash, :binary)
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
      :arguments
    ])
    |> validate_required([
      :contract_address,
      :contract_name,
      :function,
      :arguments
    ])
    |> maybe_set_hash()
  end

  def maybe_set_hash(transaction) do
    if Map.get(transaction, :hash) == nil do
      Changeset.put_change(transaction, :hash, hash(transaction.changes))
    end
  end

  def as_map_with_hash(transaction) do
    if Map.has_key?(transaction, :hash) do
      as_map(transaction)
    else
      as_map(transaction)
      |> Map.put(:hash, Map.get(transaction, :hash))
    end
  end

  def hash(params) do
    params
    |> Map.drop([
      :block_hash,
      :return_value,
      :return_code
    ])
    |> Crypto.hash()
  end

  def as_binary(block),
    do:
      as_map(block)
      |> Cbor.encode()

  def as_map(attributes) do
    attributes
    |> Map.take([
      :nonce,
      :sender,
      :function,
      :contract_name,
      :contract_address,
      :arguments,
      :return_value,
      :return_code
    ])
  end

  def sign(transaction, private_key) do
    sender = Crypto.private_key_to_public_key(private_key)
    signature = transaction
      |> Map.put(:sender, sender)
      |> as_map()
      |> Crypto.sign(private_key)
    Map.merge(transaction, %{
      sender: sender,
      signature: signature
    })
  end

  def from_signed_transaction(signed_transaction) do
    {signature, transaction} = Map.pop(signed_transaction, :signature)

    if Crypto.valid_signature?(signature, as_binary(transaction), signed_transaction.sender) do
      {:ok, struct(__MODULE__, transaction)}
    else
      {:error, :invalid_signature}
    end
  end

  def post(transaction) do
    Redis.push("transactions::queued", [as_binary(transaction)])
  end
end
