defmodule Integration.ApplyBlockTest do
  @host "http://localhost:4047"

  import Blacksmith.Factory
  import Test.Utils
  use NamedAccounts
  use ExUnit.Case

  setup do
    checkout_repo()
    deploy_and_fund_staking_contract()
    # {:ok, "0x" <> contract_address} = deploy("EllipitcoinStakingContract.bin")
    # Application.put_env(:blacksmith, :staking_contract_address, Base.decode16!(contract_address, case: :mixed))
    # #
    Redis.reset()

    on_exit(fn ->
      Redis.reset()
    end)

    :ok
  end

  test "applies blocks from remote clients" do
    genisis_block = insert(:block)

    set_balances(%{
      @alice => 100,
      @bob => 100
    })

    http_post_signed_block(
      %{
        number: 1,
        parent_hash: genisis_block.block_hash,
        transactions: [
          %{
            address: Constants.system_address(),
            contract_name: Constants.base_token_name(),
            method: :transfer,
            params: [@bob, 50]
          }
        ],
        changeset_hash: "00" |> Base.encode16()
      },
      Application.get_env(:blacksmith, :private_key)
    )
  end

  def http_post_signed_block(block, private_key) do
    encoded_block = Cbor.encode(block)
    message = <<block.number::size(64)>> <> Crypto.hash(encoded_block)
    signature = Crypto.sign_secp256k1(message, private_key)

    address = Crypto.address_from_private_key(private_key)

    HTTPoison.post(
      @host <> "/blocks",
      encoded_block,
      headers(signature)
    )
  end

  def headers(signature) do
    %{
      "Content-Type": "application/cbor",
      Authorization: "Signature " <> Base.encode16(signature, case: :lower)
    }
  end
end
