defmodule Integration.StakingTest do
  import Blacksmith.Factory
  import Test.Utils
  import Utils
  use NamedAccounts
  use ExUnit.Case
  alias Ethereum.Contracts.EllipticoinStakingContract
  alias Blacksmith.Models.{Block, Transaction}

  setup do
    checkout_repo()
    insert_contracts()
    insert(:block)
    setup_staking_contract()

    on_exit(fn ->
      Redis.reset()
    end)
  end

  test "a new block is mined on the parent chain and this node is the winner" do
    bypass = Bypass.open()
    join_network(bypass.port)
    {:ok, bypass: bypass}

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

    post(
      %{
        nonce: 1,
        function: :transfer,
        arguments: [@bob, 50]
      },
      @alices_private_key
    )

    Ethereum.Helpers.mine_block()

    assert ok(EllipticoinStakingContract.block_hash()) ==
             Base.decode16!("4C35CD192DB35E0A0EC48D6E09CADCE4FB85A7129661B77AF5D4BB547C6BC5E8")

    assert EllipticoinStakingContract.last_signature() |> Crypto.hash() ==
             Base.decode16!("486E35B33A96373A94EBA0FE70BE81A29B4C56DEF33B0DBAD132EBE104535A2D")

    assert get(%{
             private_key: @alices_private_key,
             function: :balance_of,
             arguments: [@alice]
           }) == 50
  end

  test "a new block is mined on the parent chain and another node is the winner" do
    Application.put_env(:blacksmith, :ethereum_private_key, @bobs_ethereum_private_key)

    set_balances(%{
      @alice => 100,
      @bob => 100
    })

    transaction =
      Transaction.new(
        %{
          nonce: 1,
          function: :transfer,
          arguments: [@bob, 50]
        },
        @alices_private_key
      )

    post_signed_block(
      %Block{
        number: 2,
        block_hash: <<0::256>>,
        changeset_hash: <<0::256>>,
        winner: <<0::256>>,
        transactions: [transaction]
      },
      @alices_ethereum_private_key
    )

    assert get(%{
             private_key: @alices_private_key,
             function: :balance_of,
             arguments: [@alice]
           }) == 50

    Application.put_env(:blacksmith, :ethereum_private_key, @alices_ethereum_private_key)
  end
end
