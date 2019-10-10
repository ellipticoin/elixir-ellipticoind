defmodule API.BlocksApiTest do
  alias Ellipticoind.Views.BlockView
  alias Ellipticoind.Models.Block
  alias Ellipticoind.Repo
  import Test.Utils
  import Ellipticoind.Factory
  use ExUnit.Case

  setup do
    Redis.reset()
    checkout_repo()
  end

  test "GET /blocks/:block_number:" do
    # {public_key, _private_key} = Crypto.keypair()
    #
    # block = %{
    #   contract_address: <<0::256>> <> "test",
    #   nonce: 0,
    #   gas_limit: 100000000,
    #   sender: public_key,
    #   function: :function,
    #   arguments: []
    # }
    #
    # Block.changeset(%Block{}, block)
    # |> Repo.insert()
    #
    # block_hash = Crypto.hash(block)
    block = build(:block_changeset)
    Repo.insert!(block)

    assert {:ok, response} = http_get("/blocks/#{block.number}")

    assert Cbor.decode!(response.body) == BlockView.as_map(block)
  end
end
