defmodule API.TransactionsApiTest do
  alias Ellipticoind.Models.Transaction
  alias Ellipticoind.Repo
  import Test.Utils
  use ExUnit.Case

  setup do
    Redis.reset()
    checkout_repo()
  end

  test "GET /transactions/:transaction_hash:" do
    {public_key, _private_key} = Crypto.keypair()

    transaction = %{
      contract_name: :test,
      contract_address: <<0::256>>,
      nonce: 0,
      sender: public_key,
      function: :function,
      arguments: []
    }

    Transaction.changeset(%Transaction{}, transaction)
    |> Repo.insert()

    transaction_hash = Crypto.hash(transaction)

    assert {:ok, response} = http_get("/transactions/" <> Base.url_encode64(transaction_hash))

    assert Cbor.decode!(response.body) ==
             Map.merge(transaction, %{
               hash: Transaction.hash(transaction),
               return_code: nil,
               return_value: nil
             })
  end

  test "POST /transactions with a valid  signature" do
    {public_key, private_key} = Crypto.keypair()

    unsigned_transaction = %{
      contract_name: :test,
      contract_address: <<0::256>>,
      nonce: 0,
      function: :function,
      arguments: []
    }

    signed_transaction = Transaction.sign(unsigned_transaction, private_key)
    assert {:ok, response} = http_post("/transactions", Cbor.encode(signed_transaction))

    assert response.body ==
             unsigned_transaction
             |> Map.put(:sender, public_key)
             |> Crypto.hash()
             |> Cbor.encode()

    assert response.status_code == 200
  end

  test "POST /transactions with an invalid a signature" do
    {_public_key, private_key} = Crypto.keypair()

    unsigned_transaction = %{
      contract_name: "test",
      contract_address: <<0::256>>,
      function: :function,
      arguments: []
    }

    signed_transaction = Transaction.sign(unsigned_transaction, private_key)

    signed_transaction = %{
      signed_transaction
      | signature: <<0::512>>
    }

    assert {:ok, response} = http_post("/transactions", Cbor.encode(signed_transaction))
    assert response.body == "invalid_signature"
    assert response.status_code == 401
  end
end
