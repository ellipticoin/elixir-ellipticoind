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

    bypass = Bypass.open
    join_network(bypass.port)
    {:ok, bypass: bypass}
  end

  test "a new block is mined on the parent chain and this node is the winner", %{
    bypass: bypass
  } do

    Bypass.expect_once bypass, "POST", "/blocks", fn conn ->
      signature = HTTP.SignatureAuth.get_signature(conn)
      {:ok, body, _} = Plug.Conn.read_body(conn)
      {:ok, block} = Cbor.decode(body)
      message = <<block.number::size(64)>> <> Crypto.hash(body)
      assert block.number == 0
      address = Ethereum.Helpers.private_key_to_address(@alices_ethereum_private_key)
      assert Ethereum.Helpers.valid_signature?(signature, message, address)
      Plug.Conn.resp(conn, 200, "")
    end
    set_balances(%{
      @alice => 100,
      @bob => 100
    })
    Ethereum.Helpers.mine_block()
    :timer.sleep(1000)
  end
end
