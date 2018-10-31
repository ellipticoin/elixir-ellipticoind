defmodule Models.BlockTest do
  import Test.Utils

  alias Models.{Block,Contract}
  use ExUnit.Case
  use NamedAccounts
  use OK.Pipe

  setup_all do
    Redis.reset()

    on_exit(fn ->
      Redis.reset()
    end)
  end

  describe "Block.forge/0" do
    test "it creates a new block" do
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

      block = Block.forge()

      assert block.number == 0
    end
  end
end
