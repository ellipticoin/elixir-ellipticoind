defmodule VMTest do
  @sender  Base.decode16!("509c3480af8118842da87369eb616eb7b158724927c212b676c41ce6430d334a", case: :lower)

  use ExUnit.Case

  test "VM.run_get" do
    VM.deploy(%{
      nonce: 0,
      sender: @sender,
      code: read_test_wasm("adder.wasm"),
      contract_name: "Adder",
      params: [],
    })

    assert VM.run_get(%{
      method: :add,
      address: @sender,
      contract_name: "Adder",
      params: [1, 2],
    }) == {:ok, Cbor.encode(3)}
  end


  def read_test_wasm(file_name) do
    Path.join([test_support_dir(), "wasm", file_name])
      |> File.read!
  end

  def test_support_dir() do
    Path.join([File.cwd!, "test", "support"])
  end
end
