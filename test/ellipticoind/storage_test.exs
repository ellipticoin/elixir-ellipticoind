defmodule Ellipticoind.StorageTest do
  alias Ellipticoind.Storage
  use ExUnit.Case

  setup do
    on_exit(fn ->
      File.rm_rf!(Config.rocksdb_path())
    end)
  end

  # This test passes when run indivdually but fails when
  # run with other tests
  @tag :skip
  test "Storage" do
    Storage.set(0, <<0::256>>, :test, "key", "value")
    assert Storage.get(<<0::256>>, :test, "key") == "value"
  end
end
