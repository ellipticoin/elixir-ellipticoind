defmodule TransactionProcessor.BasicTransactionProcessorTest do
  import Test.Utils
  use ExUnit.Case

  setup do
    checkout_repo()

    on_exit(fn ->
      Redis.reset()
    end)
  end

  test "adder.wasm" do
    insert_test_contract(:adder)

    assert run_transaction(%{
             contract_name: :adder,
             function: :add,
             arguments: [1, 2]
           }) == {:ok, 3}
  end

  test "env.wasm" do
    insert_test_contract(:env)

    assert run_transaction(
             %{
               contract_name: :env,
               function: :block_number
             },
             %{
               number: 1
             }
           ) == {:ok, 1}
  end
end
