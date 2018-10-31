defmodule Models.ContractTest do
  import Test.Utils

  alias Models.Contract
  use ExUnit.Case
  use NamedAccounts
  use OK.Pipe

  setup_all do
    Redis.reset()

    on_exit(fn ->
      Redis.reset()
    end)
  end

  describe "Contract.execute/1" do
    test "it works with token transfers" do
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

      TransactionProccessor.proccess_transactions(1)
      TransactionProccessor.wait_until_done()

      assert Contract.get(%{
               address: Constants.system_address(),
               contract_name: Constants.base_token_name(),
               method: :balance_of,
               params: [@alice]
             })
             ~>> Cbor.decode!() == 50

      assert Contract.get(%{
               address: Constants.system_address(),
               contract_name: Constants.base_token_name(),
               method: :balance_of,
               params: [@bob]
             })
             ~>> Cbor.decode!() == 150
    end
  end
end
