defmodule Integration.StakingTest do
  import Test.Utils
  use NamedAccounts
  use ExUnit.Case

  setup do
    Redis.reset()

    {:ok, contract_address} = deploy("EllipitcoinStakingContract.bin")

    on_exit(fn ->
      Redis.reset()
    end)

    :ok
  end

  test "block winners are selected randomly" do
  end
end
