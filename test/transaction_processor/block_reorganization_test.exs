defmodule TransactionProcessor.BlockReorganizationTest do
  use ExUnit.Case
  alias Ellipticoind.Models.Block.TransactionProcessor
  import Test.Utils

  setup do
    Redis.reset()
    checkout_repo()
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
  test ".revert_state reverts state back to a specified block number" do
    insert_test_contract(:stack)
    push(:A, 1)
    push(:B, 2)
    push(:C, 3)
    TransactionProcessor.revert_to(1)
    push(:D, 2)
    push(:E, 3)
    push(:F, 4)

    assert get_stack() == [:A, :D, :E, :F]
  end

  def get_stack(), do: get_value(:stack, "value")

  def push(value, block_number),
    do:
      run_transaction(%{
        contract_name: :stack,
        function: :push,
        arguments: [value]
      }, %{
        number: block_number,
      })
end
