defmodule Models.BlockTest do
  alias Models.Block
  alias Blacksmith.Repo
  import Blacksmith.Factory
  use ExUnit.Case

  test "Blockchain.latest" do
    insert_list(5, :block)

    assert length(Block.latest(3)
    |> Repo.all) == 3
  end
end
