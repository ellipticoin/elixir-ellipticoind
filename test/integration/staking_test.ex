defmodule Integration.BaseTokenTest do
  @host "http://localhost:4047"
  @adder_contract_code File.read!("test/support/wasm/adder.wasm")

  import Utils
  import Test.Utils
  use NamedAccounts
  use ExUnit.Case

  setup do
    Redis.reset()

    {:ok, contract_address} = deploy("EllipitcoinStakingContract.bin")
    IO.inspect contract_address
    on_exit(fn ->
      Redis.reset()
    end)

    :ok
  end

  test "block winners are selected randomly" do
  end
end
