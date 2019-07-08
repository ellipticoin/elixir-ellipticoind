defmodule Ellipticoind.StorageTest do
  alias Ellipticoind.Storage
  use ExUnit.Case

  test "Storage" do
    Storage.set(0, <<0::256>>, :test, "key", "value")
    assert Storage.get(<<0::256>>, :test, "key") == "value"
  end
end
