defmodule TransactionProcessorTest do
  use ExUnit.Case
  alias Node.Models.{Contract, Block}
  alias Node.Repo
  import Utils
  import Test.Utils

  setup do
    checkout_repo()

    on_exit(fn ->
      Redis.reset()
    end)
  end

  test "adder.wasm" do
    insert_test_contract(:adder)

    assert process_transaction(%{
             sender: <<0>>,
             nonce: 0,
             contract_name: :adder,
             function: :add,
             arguments: [1, 2],
             return_value: 3,
             return_code: 0
           }) == 3
  end

  test "env.wasm" do
    insert_test_contract(:env)

    assert process_transaction(
             %{
               sender: <<0>>,
               nonce: 0,
               contract_name: :env,
               function: :block_number,
               arguments: [],
               return_value: 1,
               return_code: 0
             },
             %{
               block_number: 1,
               block_winner: <<>>,
               block_hash: <<>>
             }
           ) == 1
  end

  test ".process_transaction fails if the transaction results are different than the ones that were provided" do
    insert_test_contract(:adder)

    assert TransactionProcessor.process(%Block{
             transactions: [
               %{
                 sender: <<0>>,
                 nonce: 0,
                 contract_name: :adder,
                 function: :add,
                 arguments: [1, 2],
                 return_value: 4,
                 return_code: 0
               }
             ]
           }) == {:error, [{:return_value_mismatch, 3, 4}]}

    assert TransactionProcessor.process(%Block{
             transactions: [
               %{
                 sender: <<0>>,
                 nonce: 0,
                 contract_name: :adder,
                 function: :add,
                 arguments: [1, 2],
                 return_value: 3,
                 return_code: 2
               }
             ]
           }) == {:error, [{:return_code_mismatch, 0, 2}]}
  end

  @doc """
  If a new block comes in with a higher total difficulty than the current
  highest block we need to reverse the results of transaction in orphaned blocks.

  Take for example this case:

  Start with a chain:

  A --- B --- C

  Where total block difficulty increases in alphabetical order.


  Now imagine block F comes in with a higher total difficulty than C.
  The chain now looks like this:
  

         - B --- C
        /
       /
  A ----
       \
        \
         - D --- E ---F

  B and C are now orphaned blocks.
  Therefore all transactions that were included in B and C that aren't
  included in D and E need to be reverted.

  To do this first we revert the state back to before the fork:

  A

  Then we apply the new blocks:


  A --- D --- E --- F
  """
  test ".process_transaction reverts state changes of transactions that aren't on this chain" do
  end

  def insert_test_contract(contract_name) do
    %Contract{
      address: <<0::256>>,
      name: contract_name,
      code: File.read!(test_wasm_path(Atom.to_string(contract_name)))
    }
    |> Repo.insert!()
  end

  def process_transaction(transaction, env \\ %{}),
    do:
      transaction
      |> (&TransactionProcessor.process(%Block{transactions: [&1]}, env)).()
      |> return_value()

  def return_value(results),
    do:
      results
      |> ok
      |> Map.get(:transactions)
      |> Enum.at(0)
      |> Map.get(:return_value)
end
