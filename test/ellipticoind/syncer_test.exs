defmodule Ellipticoind.SyncerTest do
  import Test.Utils
  use NamedAccounts
  use ExUnit.Case, async: false
  alias Ellipticoind.Repo
  alias Ellipticoind.Syncer
  alias Test.MockEllipticoinClient
  import Ellipticoind.Factory
  use OK.Pipe

  setup do
    checkout_repo()

    :ok
  end


  test "miner syncs on startup" do
    MockEllipticoinClient.start_link(%{})
    blocks =  build_list(4, :block_changeset)
      |> Enum.map(&Ecto.Changeset.apply_changes/1)
      |> Enum.map(&Repo.preload(&1, :transactions))
    MockEllipticoinClient.push_blocks(Enum.slice(blocks, 0, 2))

    Syncer.start_link(%{})
    MockEllipticoinClient.push_blocks(Enum.slice(blocks, 2, 4))
    block = poll_for_block(3)
    assert block.number == 3
  end
end
