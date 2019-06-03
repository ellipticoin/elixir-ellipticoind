defmodule Ellipticoind.StorageTest do
  alias Ellipticoind.Storage
  use ExUnit.Case, async: false

  test "Storage" do
    Storage.set(<<0::256>>, :test, 0, "key", "value")
    assert Storage.get(<<0::256>>, :test, "key") == "value"
  end
end
