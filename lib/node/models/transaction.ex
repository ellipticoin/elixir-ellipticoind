defmodule Node.Models.Transaction do
  use Ecto.Schema
  alias Node.Models.Contract
  alias Node.Ecto.Types
  alias Node.Repo
  import Ecto.Changeset

  schema "transactions" do
    field(:hash, :binary, primary_key: true)
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

    timestamps()
  end

  @doc false
  def changeset(transaction, attrs) do
    attrs = set_hash(attrs)

    transaction
    |> cast(attrs, [
      :sender,
      :nonce,
      :hash,
      :block_hash,
      :contract_address,
      :contract_name,
      :return_code,
      :return_value,
      :function,
      :arguments
    ])
    |> validate_required([
      :hash,
      :contract_address,
      :contract_name,
      :return_code,
      :function,
      :arguments
    ])
  end

  def set_hash(attrs) do
    Map.put(attrs, :hash, Crypto.hash(as_binary(attrs)))
  end

  def as_map(attributes) do
    attributes
    |> Map.take([
      :hash,
      :nonce,
      :block_hash,
      :sender,
      :function,
      :contract_name,
      :contract_address,
      :arguments,
      :return_value,
      :return_code
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
  end

  def sign(transaction, private_key) do
    sender = Crypto.private_key_to_public_key(private_key)
    signature = Crypto.sign(as_map(transaction), private_key)

    transaction
    |> Map.put(:sender, sender)
    |> Map.put(:signature, signature)
  end

  def post(parameters) do
    transaction_bytes =
      parameters
      |> with_code()
      |> Cbor.encode()

    Redis.push("transactions::queued", [transaction_bytes])
  end

  def as_binary(transaction),
    do:
      as_map(transaction)
      |> Cbor.encode()
end
