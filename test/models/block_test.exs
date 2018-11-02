defmodule Models.BlockTest do
  import Blacksmith.Factory
  import Test.Utils

  alias Models.{Block,Contract}
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
      assert Base.encode16(block.changeset_hash) == "494C168DB398CAEC106DF7CEE1B3F681BC9A5286A6B8E9C23647D6299A9C3E5F"
      assert Base.encode16(block.block_hash) == "4BB5F562161C5B5AA250C1DF5AE97890EC4A82D31364CA90B575BEB71495B754"
    end
  end
end
