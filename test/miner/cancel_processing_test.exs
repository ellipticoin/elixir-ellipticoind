defmodule Miner.CancelProcessingTest do
  alias Ellipticoind.{Miner, Memory}
  use ExUnit.Case
  import Test.Utils
  use TemporaryEnv

  setup do
    checkout_repo()

    on_exit(fn ->
      Redis.reset()
    end)
  end

  test ".cancel reverts state that was changed" do
    insert_test_contract(:stack)

    TemporaryEnv.put :ellipticoind, :transaction_processing_time, 2000 do
      post_transaction(%{
        contract_name: :stack,
        function: :push,
        arguments: [:A]
      })

      pid =
        spawn(fn ->
          Miner.process_new_block()
        end)

      send(pid, :cancel)
      :timer.sleep(500)
    end

    assert Memory.get_value(<<0::256>>, :stack, "value") == nil
  end
end
