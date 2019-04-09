defmodule Integration.MiningTest do
  import Test.Utils
  use NamedAccounts
  use ExUnit.Case
  alias Node.Models.{Block, Contract, Transaction}
  use OK.Pipe

  setup do
    checkout_repo()
    insert_contracts()

    on_exit(fn ->
      Redis.reset()
    end)
  end

  test "mining a block" do
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

    P2P.Transport.Test.subscribe_to_test_broadcasts(self())
    Miner.start_link()

    new_block =
      receive do
        {:p2p, _from, message} -> message
      end
      |> Block.from_binary()

    assert new_block.number == 0

    assert new_block.transactions == [
             %{
               arguments: Cbor.encode([@bob, 50]),
               contract_address: <<0::256>>,
               contract_name: :BaseToken,
               function: :transfer,
               return_code: 0,
               return_value: nil,
               sender: nil
             }
    ]
    assert is_integer(new_block.proof_of_work_value)
    assert byte_size(new_block.hash) == 32
    assert byte_size(new_block.changeset_hash) == 32
    refute new_block.hash == <<0::256>>
    refute Map.has_key?(new_block, :parent_hash)


    assert Contract.get(%{
             address: <<0::256>>,
             contract_name: :BaseToken,
             function: :balance_of,
             arguments: [@alice]
           })
           ~>> Cbor.decode!() == 50
  end

  test "a new block is mined on the parent chain and another node is the winner" do
    set_balances(%{
      @alice => 100,
      @bob => 100
    })
    transaction =
      %Transaction{
        nonce: 1,
        contract_name: :BaseToken,
        contract_address: <<0::256>>,
        function: :transfer,
        return_code: 0,
        return_value: nil,
        arguments: [@bob, 50]
      }
      |> Transaction.sign(@alices_private_key)

    block_bytes =
      %Block{
        number: 0,
        proof_of_work_value: 50,
        block_hash: <<0::256>>,
        changeset_hash:
          Base.decode16!("A0EACAF6511F17AEBE17BC73E76F7387EF0CB5FD57F025697F7AE0E00E6FB532"),
        transactions: [transaction],
        winner: @bob
      }
      |> Block.as_binary()

    P2P.Transport.Test.receive(block_bytes)
    new_block = poll_for_next_block()
    assert Contract.get(%{
             address: <<0::256>>,
             contract_name: :BaseToken,
             function: :balance_of,
             arguments: [@alice]
           })
           ~>> Cbor.decode!() == 50
  end
end
