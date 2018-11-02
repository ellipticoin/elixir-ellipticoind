defmodule Integration.ApplyBlockTest do
  @host "http://localhost:4047"

  import Test.Utils
  use NamedAccounts
  use ExUnit.Case

  setup do
    Redis.reset()

    on_exit(fn ->
      Redis.reset()
    end)

    :ok
  end

  test "applies blocks from remote clients" do
    # genisis_block = insert(:block)
    # set_balances(%{
    #   @alice => 100,
    #   @bob => 100
    # })

    # http_post_signed_block(
    #   %{
    #     number: 1,
    #     parent_hash: genisis_block.block_hash,
    #     transactions: [
    #       address: Constants.system_address(),
    #       contract_name: Constants.base_token_name(),
    #       method: :transfer,
    #       params: [@bob, 50]
    #     ],
    #     changeset_hash: "00" |> Base.encode16
    #   }
    # )
  end

  def http_post_signed_block(message, private_key) do
    signature = Crypto.sign_sepk256k1(message, private_key)

    HTTPoison.post(
      @host <> "/block",
      message
      # headers(signature)
    )
  end
end
