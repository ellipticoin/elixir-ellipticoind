defmodule Integration.BlockReorganizationTest do
  use ExUnit.Case
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
  test ".process_transaction reverts state changes of transactions that aren't on this chain" do
    insert_test_contract(:stack)

    run_transaction(
      %{
        contract_name: :stack,
        function: :push,
        arguments: [:A],
      }
    )

    # stack_contract_address = <<0::256>> <> ("stack" |> pad_trailing(32))
    # IO.inspect Redis.get_binary(stack_contract_address <> "values")
  end
end
