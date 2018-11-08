defmodule Integration.BaseTokenTest do
  import Test.Utils
  use NamedAccounts
  use ExUnit.Case

  setup do
    Redis.reset()

    on_exit(fn ->
      Redis.reset()
    end)

    :ok
  end

  test "send tokens asynchronously" do
    set_balances(%{
      @alice => 100,
      @bob => 100
    })

    post(%{
      private_key: @alices_private_key,
      nonce: 2,
      method: :transfer,
      params: [@bob, 50]
    })

    TransactionProccessor.proccess_transactions(1)
    TransactionProccessor.wait_until_done()

    assert get(%{
      private_key: @alices_private_key,
      method: :balance_of,
      params: [@alice]
    }) == 50
  end
end
