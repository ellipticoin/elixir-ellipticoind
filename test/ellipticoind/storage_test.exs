defmodule Ellipticoind.StorageTest do
  alias Ellipticoind.Storage
  import Test.Utils
  use ExUnit.Case

  setup do
    checkout_repo()

    on_exit(fn ->
      Redis.reset()
    end)
  end

  test "Storage" do
    Storage.set(<<0::256>>, :test, 0, "key", "value")
    assert Storage.get(<<0::256>>, :test, "key") == "value"
  end
end
