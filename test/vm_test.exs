defmodule VMTest do
  @sender "509c3480af8118842da87369eb616eb7b158724927c212b676c41ce6430d334a"
          |> Base.decode16!(case: :lower)

  import Test.Utils
  use ExUnit.Case

  setup_all do
    Redis.reset()

    on_exit(fn ->
      Redis.reset()
    end)
  end

  test "TransactionProccessor proccesses transactions" do
    counter_code = read_test_wasm("counter.wasm")

    TransactionPool.add(%{
      code: counter_code,
      env: %{
        sender: @sender,
        address: @sender,
        contract_name: "Counter"
      },
      method: :increment_by,
      params: [
        1
      ]
    })

    TransactionProccessor.proccess_transactions(1)
    TransactionProccessor.wait_until_done()

    TransactionPool.add(%{
      code: counter_code,
      env: %{
        sender: @sender,
        address: @sender,
        contract_name: "Counter"
      },
      method: :increment_by,
      params: [
        1
      ]
    })

    TransactionProccessor.proccess_transactions(1)
    TransactionProccessor.wait_until_done()

    assert VM.get(%{
             code: counter_code,
             env: %{
               sender: @sender,
               address: @sender,
               contract_name: "Counter"
             },
             method: :get_count,
             params: []
           }) == {:ok, Cbor.encode(2)}
  end
end
