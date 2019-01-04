defmodule Models.TransactionTest do
  import Test.Utils

  alias Blacksmith.Models.{Contract,Transaction}
  use ExUnit.Case
  use NamedAccounts
  use OK.Pipe

  setup_all do
    checkout_repo()
    insert_tesetnet_contracts()
    Redis.reset()

    on_exit(fn ->
      Redis.reset()
    end)
  end

  describe "Transaction.post/1" do
    test "it works with token transfers" do
      set_balances(%{
        @alice => 100,
        @bob => 100
      })

      Transaction.post(%{
        address: <<0::256>>,
        contract_name: :BaseToken,
        function: :transfer,
        nonce: 0,
        arguments: [@bob, 50],
        sender: @alice
      })

      TransactionProcessor.proccess_transactions(100)
      TransactionProcessor.wait_until_done()
      assert Contract.get(%{
               address: <<0::256>>,
               contract_name: :BaseToken,
               function: :balance_of,
               arguments: [@alice]
             })
             ~>> Cbor.decode!() == 50

      assert Contract.get(%{
               address: <<0::256>>,
               contract_name: :BaseToken,
               function: :balance_of,
               arguments: [@bob],
               sender: @alice,
             })
             ~>> Cbor.decode!() == 150
    end
  end
end
