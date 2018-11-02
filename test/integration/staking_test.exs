defmodule Integration.StakingTest do
  import Test.Utils
  use NamedAccounts
  use ExUnit.Case

  setup do
    Redis.reset()

    {:ok, "0x" <> contract_address} = deploy("EllipitcoinStakingContract.bin")
    IO.inspect contract_address
    Application.put_env(:blacksmith, :staking_contract_address, Base.decode16!(contract_address, case: :mixed))

    on_exit(fn ->
      Redis.reset()
    end)

    :ok
  end

  test "block winners are selected randomly" do
  end
end
