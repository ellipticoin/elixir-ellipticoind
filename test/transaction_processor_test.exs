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

  test "adder.wasm" do
    assert process(:adder, %{
        sender: <<0>>,
        function: :add,
        arguments: [1, 2]
    }) == 3
  end

  test "env.wasm" do
    assert process(:env, %{
        sender: <<0>>,
        function: :block_number,
        arguments: []
    }, %{
      block_number: 1,
      block_winner: <<>>,
      block_hash: <<>>,
    }) == 1

  end

  def process(contract_name, transaction, env \\ nil) do
    transaction = transaction
      |> Map.merge(%{
        address: <<0::256>>,
        contract_name: contract_name,
      })
    %Contract{
      address: <<0::256>>,
      name: contract_name,
      code: File.read!(test_wasm_path(Atom.to_string(contract_name)))
    }
    |> Repo.insert!()

    %{
      transactions: [transaction_result],
    } = if is_nil(env) do
      TransactionProcessor.process([transaction])
    else
      TransactionProcessor.process([transaction], env)
    end

    transaction_result.return_value
  end
end

