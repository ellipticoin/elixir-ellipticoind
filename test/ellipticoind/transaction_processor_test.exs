defmodule Ellipticoind.TransactionProcessorTest do
  alias Ellipticoind.Memory
  alias Ellipticoind.Storage
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
            contract_address: <<0::256>> <> "adder",
             function: :add,
             arguments: [1, 2]
           }) == {:ok, 3}
  end

  test "caller.wasm - calls return values" do
    insert_test_contract(:caller)
    insert_test_contract(:adder)

    assert run_transaction(%{
             contract_address: <<0::256>> <> "caller",
             function: :call,
             arguments: [:adder, :add, [1, 2]]
           }) == {:ok, 3}
  end

  test "caller.wasm - sets state" do
    insert_test_contract(:caller)
    insert_test_contract(:state)

    assert run_transaction(%{
             contract_address: <<0::256>> <> "caller",
             function: :call,
             arguments: [:state, :set_memory, [:test]]
           }) == {:ok, nil}
    assert Memory.get_value(<<0::256>>, :state, "value") == :test
  end

  test "caller.wasm - returns caller" do
    insert_test_contract(:caller)
    insert_test_contract(:caller, :caller2)

    assert run_transaction(%{
      contract_address: <<0::256>> <> "caller",
      function: :call,
      arguments: [:caller2, :caller, []]
    }) == {:ok, <<0::256>> <> "caller"}
  end

  test "env.wasm" do
    insert_test_contract(:env)

    assert run_transaction(
             %{
               contract_address: <<0::256>> <> "env",
               function: :block_number
             },
             %{
               number: 1
             }
           ) == {:ok, 1}
  end

  test "state.wasm - memory" do
    insert_test_contract(:state)

    run_transaction(%{
      contract_address: <<0::256>> <> "state",
      function: :set_memory,
      arguments: [:test]
    })

    assert Memory.get_value(<<0::256>>, :state, "value") == :test
  end

  test "state.wasm - storage" do
    insert_test_contract(:state)

    run_transaction(%{
      contract_address: <<0::256>> <> "state",
      function: :set_storage,
      arguments: [:test]
    })

    assert Storage.get_value(<<0::256>>, :state, "value") == :test
  end
end
