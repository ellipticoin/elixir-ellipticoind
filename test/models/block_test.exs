defmodule Models.BlockTest do
  alias Models.Block
  alias Blacksmith.Repo
  import Blacksmith.Factory
  use ExUnit.Case

  test "Blockchain.latest" do
    insert_list(5, :block)

    assert Block.latest(3)
    |> Repo.all
    |> length == 3
  end
end
