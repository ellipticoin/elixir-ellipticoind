defmodule P2P.TransactionProcessorTest do
  use ExUnit.Case
  alias Node.Models.Contract
  alias Node.Repo
  import Test.Utils

  setup do
    checkout_repo()

    on_exit(fn ->
      Redis.reset()
    end)
  end

  test ".process" do
    %Contract{
      address: <<0::256>>,
      name: :adder,
      code: File.read!(test_wasm_path("adder"))
    }
    |> Repo.insert!()

    %{
      transactions: [transaction],
    } = TransactionProcessor.process([%{
        sender: <<0>>,
        nonce: 1,
        contract_name: :adder,
        contract_address: <<0::256>>,
        function: :add,
        arguments: [1, 2]
    }])

    assert transaction.return_value == 3

  end
end
