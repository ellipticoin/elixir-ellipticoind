defmodule Integration.StakingTest do

  import Blacksmith.Factory
  import Test.Utils
  import Utils
  use NamedAccounts
  use ExUnit.Case
  alias Ethereum.Contracts.EllipticoinStakingContract
  alias Models.Block

  setup do
    checkout_repo()
    insert(:block)

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
      address = Ethereum.Helpers.private_key_to_address(@alices_ethereum_private_key)
      assert Ethereum.Helpers.valid_signature?(signature, message, address)
      assert block.number == 0

      Plug.Conn.resp(conn, 200, "")
    end

    set_balances(%{
      @alice => 100,
      @bob => 100
    })
    Ethereum.Helpers.mine_block()
    :timer.sleep(1000)
    assert ok(EllipticoinStakingContract.block_hash()) == Base.decode16!("C850B0ACDA3BA6CDCAD215988A38EB0382178EA98923A46BEC7BC1EBF0B72321")
    assert ok(EllipticoinStakingContract.last_signature()) == Base.decode16!("1CAEF4C92014B175841509EA7C51887865977FE27F69269CB1F368D0679E6E016609278B84CF0A666D8C0CA5F524E07DB618BBB64ADBFD2362D0B22EC3B8A0DE05")
    # Carol is the winner of the second block
    post_signed_block(%Block{number: 2}, @carols_ethereum_private_key)
  end
end
