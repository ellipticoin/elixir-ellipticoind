defmodule API.MemoryApiTest do
  import Test.Utils
  use ExUnit.Case
  alias Ellipticoind.Memory

  setup do
    Redis.reset()
    checkout_repo()
  end

  test "requesting memory" do
    contract_name = :test
    address = <<0::256>>
    block_number = 0
    memory_key = "key"
    value = "value"

    Memory.set(address, contract_name, block_number, memory_key, value)

    key = (address <> Atom.to_string(contract_name) |> Binary.pad_trailing(64)) <> memory_key
    
    {:ok, %{body: body}} = http_get("/memory/#{Base.url_encode64(key)}")
    assert body == "value"
  end
end
