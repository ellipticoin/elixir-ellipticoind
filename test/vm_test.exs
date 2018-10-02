defmodule VMTest do
  @db Db.Redis
  @sender "509c3480af8118842da87369eb616eb7b158724927c212b676c41ce6430d334a"
          |> Base.decode16!(case: :lower)

  use ExUnit.Case

  test "TransactionProccessor proccesses transactions" do
    @db.reset()
    TransactionProccessor.start_link()
    IO.inspect "deploying"
    deploy(:Counter, read_test_wasm("counter.wasm"), @sender, 1)
    IO.inspect "deployed"

    TransactionPool.add(%{
      sender: @sender,
      nonce: 2,
      address: @sender,
      contract_name: :Counter,
      method: :increment_by,
      params: [
        3
      ]
    })
    TransactionPool.wait_for_transaction(@sender, 2)
    TransactionPool.add(%{
      sender: @sender,
      nonce: 3,
      address: @sender,
      contract_name: :Counter,
      method: :increment_by,
      params: [
        5
      ]
    })
    TransactionPool.wait_for_transaction(@sender, 3)

    assert VM.get(%{
      method: :get_count,
      address: @sender,
      contract_name: :Counter,
      params: [],
    }) == {:ok, Cbor.decode(8)}
  end

  def read_test_wasm(file_name) do
    Path.join([test_support_dir(), "wasm", file_name])
    |> File.read!()
  end

  def test_support_dir() do
    Path.join([File.cwd!(), "test", "support"])
  end

  def deploy(contract_name, contract_code, sender, nonce) do
    TransactionPool.add(%{
      sender: sender,
      nonce: nonce,
      address: Constants.system_address(),
      contract_name: :UserContracts,
      method: :deploy,
      params: [
        contract_name,
        contract_code
      ]
    })


    TransactionPool.subscribe(sender, nonce, self())

    {return_code, result} = receive do
      {:transaction, :done, <<return_code::size(32), result::binary>>} -> {return_code, result}
      _ -> raise "Error deploying #{contract_name}"
    end
    #
    # IO.puts "Return code: #{inspect return_code}"
    # if result == <<>> do
    #   IO.puts "No return message"
    # else
    #   IO.puts "Return message: #{inspect Cbor.decode!(result)}"
    # end
  end
end
