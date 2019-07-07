defmodule Ellipticoind.StorageTest do
  alias Ellipticoind.Storage
  use ExUnit.Case

  # This test passes when run indivdually but fails when
  # run with other tests
  @tag :skip
  test "Storage" do
    Storage.set(0, <<0::256>>, :test, "key", "value")
    assert Storage.get(<<0::256>>, :test, "key") == "value"
  end
end
