defmodule Ellipticoind.Models.TransactionTest do
  use ExUnit.Case
  alias Ellipticoind.Models.Transaction

  test "Transaction.from_signed_transaction returns :ok with a valid signature" do
    {public_key, private_key} = Crypto.keypair()

    unsigned_transaction = %{
      sender: public_key,
      contract_name: "test",
      contract_address: <<0::256>>,
      function: :function,
      arguments: []
    }

    signed_transaction = Transaction.sign(unsigned_transaction, private_key)
    assert {:ok, unsigned_transaction} == Transaction.from_signed_transaction(signed_transaction)
  end

  test "Transaction.from_signed_transaction returns :error with an invalid signature" do
    {public_key, _private_key} = Crypto.keypair()

    unsigned_transaction = %{
      sender: public_key,
      contract_name: "test",
      contract_address: <<0::256>>,
      function: :function,
      arguments: []
    }

    signature = <<0::512>>
    signed_transaction = Map.put(unsigned_transaction, :signature, signature)
    assert {:error, :invalid_signature} == Transaction.from_signed_transaction(signed_transaction)
  end
end
