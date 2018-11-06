defmodule Models.BlockTest do
  import Blacksmith.Factory
  import Test.Utils

  alias Models.{Block, Contract}
  use ExUnit.Case, async: true
  use NamedAccounts
  use OK.Pipe

  setup_all do
    Redis.reset()

    on_exit(fn ->
      Redis.reset()
    end)
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Blacksmith.Repo)
  end

  describe "Block.forge/0" do
    test "it creates a new block" do
      genisis_block = insert(:block)

      set_balances(%{
        @alice => 100,
        @bob => 100
      })

      Contract.post(%{
        address: Constants.system_address(),
        contract_name: Constants.base_token_name(),
        method: :transfer,
        params: [@bob, 50],
        sender: @alice
      })

      {:ok, block} = Block.forge(@alice)

      assert block.number == 0
      assert block.parent == genisis_block

      assert Base.encode16(block.changeset_hash) ==
               "CDA177296E5DDD1718F58FD4A98F816BB4A4228CF981234BE904180D8354DD08"

      assert Base.encode16(block.block_hash) ==
               "F28E341B79207AE42955384780EB9FF210F481AB1DA6170A9E537AE89F6D0A9A"
    end
  end
end
