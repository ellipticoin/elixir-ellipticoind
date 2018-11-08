defmodule Integration.StakingTest do
  @host "http://localhost:4047"

  import Blacksmith.Factory
  import Test.Utils
  use NamedAccounts
  use ExUnit.Case
  alias Ethereum.Helpers

  setup do
    checkout_repo()
    genisis_block = insert(:block)

    StakingContractMonitor.disable()
    {:ok, contract_address} = deploy_and_fund_staking_contract()
    StakingContractMonitor.enable()
    Redis.reset()


    Application.put_env(
      :blacksmith,
      :staking_contract_address,
      contract_address
    )

    on_exit(fn ->
      Redis.reset()
    end)

    :ok
  end

  test "a new block is mined on the parent chain and this node is the winner" do

    set_balances(%{
      @alice => 100,
      @bob => 100
    })
    Ethereum.Helpers.mine_block()
    TransactionProccessor.wait_until_done()
    :timer.sleep(1000)
  end

  def http_post_signed_block(block, account) do
    encoded_block = Cbor.encode(block)
    message = <<block.number::size(64)>> <> Crypto.hash(encoded_block)
    {:ok, signature} = Helpers.sign(account, message)

    HTTPoison.post(
      @host <> "/blocks",
      encoded_block,
      headers(signature)
    )
  end
end
