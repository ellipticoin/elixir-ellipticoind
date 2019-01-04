defmodule Integration.StakingTest do
  import Blacksmith.Factory
  import Test.Utils
  import Utils
  use NamedAccounts
  use ExUnit.Case
  alias Ethereum.Contracts.EllipticoinStakingContract
  alias Blacksmith.Models.Block

  setup do
    checkout_repo()
    insert(:block)

    StakingContractMonitor.disable()
    deploy_test_contracts()
    fund_staking_contract()
    set_public_moduli()
    StakingContractMonitor.enable()
    Redis.reset()

    on_exit(fn ->
      Redis.reset()
    end)

    bypass = Bypass.open()
    join_network(bypass.port)
    {:ok, bypass: bypass}
  end

  test "a new block is mined on the parent chain and this node is the winner", %{
    bypass: bypass
  } do
    Bypass.expect_once(bypass, "POST", "/blocks", fn conn ->
      signature = HTTP.SignatureAuth.get_signature(conn)
      {:ok, body, _} = Plug.Conn.read_body(conn)
      {:ok, block} = Cbor.decode(body)
      message = <<block.number::size(64)>> <> Crypto.hash(body)
      address = Ethereum.Helpers.private_key_to_address(@alices_ethereum_private_key)
      assert Ethereum.Helpers.valid_signature?(signature, message, address)
      assert block.number == 1

      Plug.Conn.resp(conn, 200, "")
    end)

    set_balances(%{
      @alice => 100,
      @bob => 100
    })

    post(%{
      private_key: @alices_private_key,
      nonce: 1,
      method: :transfer,
      params: [@bob, 50]
    })

    Ethereum.Helpers.mine_block()
    :timer.sleep(1000)

    assert ok(EllipticoinStakingContract.block_hash()) ==
             Base.decode16!("800158ADD9277781E26EC461D4322CC0F56DF4EB8BDED7E812576D79CE204C8E")

    assert EllipticoinStakingContract.last_signature() |> Crypto.hash() ==
             Base.decode16!("486E35B33A96373A94EBA0FE70BE81A29B4C56DEF33B0DBAD132EBE104535A2D")

    assert get(%{
             private_key: @alices_private_key,
             method: :balance_of,
             params: [@alice]
           }) == 50

    # Bob is the winner of the second block
    post_signed_block(
      %Block{
        number: 2,
        block_hash: <<0::256>>,
        changeset_hash: <<0::256>>,
        winner: <<0::256>>
      },
      @carols_ethereum_private_key
    )
  end
end
