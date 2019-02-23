defmodule Models.BlockTest do
  import Blacksmith.Factory
  import Test.Utils
  import Ethereum.Helpers, only: [my_ethereum_address: 0]

  alias Blacksmith.Models.{Block, Transaction}
  use ExUnit.Case, async: true
  use NamedAccounts
  use OK.Pipe

  setup do
    checkout_repo()
    insert_contracts()
    setup_staking_contract()

    on_exit(fn ->
      Redis.reset()
    end)
  end

  describe "Block.should_forge?/1" do
    test "it returns false if the we've already forged this block" do
      genisis_block = insert(:block)

      assert Block.should_forge?(%{
               ethereum_block_number: genisis_block.ethereum_block_number,
               ethereum_block_hash: genisis_block.ethereum_block_hash,
               ethereum_difficulty: genisis_block.ethereum_difficulty,
               winner: <<0::256>>
             }) == false
    end

    test "it returns false if the ethereum block number is less than the current best ethereum block number" do
      insert(:block, ethereum_block_number: 1)

      assert Block.should_forge?(%{
               ethereum_block_number: 0,
               ethereum_block_hash: <<0::256>>,
               ethereum_difficulty: 0,
               winner: my_ethereum_address()
             }) == false
    end

    test "it returns false if we're not the winner of this block" do
      genisis_block = insert(:block)

      assert Block.should_forge?(%{
               ethereum_block_number: genisis_block.number + 1,
               ethereum_block_hash: <<0::256>>,
               ethereum_difficulty: 0,
               winner: <<0::256>>
             }) == false
    end

    test "it returns true if this block should be forged" do
      genisis_block = insert(:block)

      assert Block.should_forge?(%{
               ethereum_block_number: genisis_block.number + 1,
               ethereum_block_hash: <<0::256>>,
               ethereum_difficulty: 0,
               winner: my_ethereum_address()
             }) == true
    end

    test "it returns true if this block should be forged and there's no genisis block" do
      assert Block.should_forge?(%{
               ethereum_block_number: 0,
               ethereum_block_hash: <<0::256>>,
               ethereum_difficulty: 0,
               winner: my_ethereum_address()
             }) == true
    end
  end

  describe "Block.forge/0" do
    test "it creates a new block" do
      genisis_block = insert(:block)

      set_balances(%{
        @alice => 100,
        @bob => 100
      })

      Transaction.post(%{
        contract_address: <<0::256>>,
        contract_name: :BaseToken,
        function: :transfer,
        arguments: [@bob, 50],
        sender: @alice
      })

      {:ok, block} = Block.forge(%{
        ethereum_difficulty: 0,
        ethereum_block_hash: <<0::256>>,
        ethereum_block_number: 1,
        winner: <<0::256>>,
        number: 1,
      })

      assert block.number == 1
      assert block.parent == genisis_block

      assert Base.encode16(block.changeset_hash) ==
               "0212F77EA6539811CCBD42064B8D0399DAF114F06B4C36C56AE0B26E36DDCFEE"

      assert Base.encode16(block.block_hash) ==
               "7F50AB9AD65D94D5E626237B6E4D986A62D7C1061EF6805676987F7A3B793D3C"
    end
  end
end
