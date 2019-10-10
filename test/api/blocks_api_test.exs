defmodule API.BlocksApiTest do
  alias Ellipticoind.Views.BlockView
  alias Ellipticoind.Repo
  import Test.Utils
  import Ellipticoind.Factory
  use ExUnit.Case

  setup do
    Redis.reset()
    checkout_repo()
  end

  test "GET /blocks/:block_number:" do
    block_changeset = build(:block_changeset)
    block = Repo.insert!(block_changeset)

    assert {:ok, response} = http_get("/blocks/#{block.number}")

    assert Cbor.decode!(response.body) == BlockView.as_map(block)
  end

  test "GET /blocks" do
    block_changesets = build_list(3, :block_changeset)
    blocks = block_changesets
             |> Enum.map(&Repo.insert!/1)

    assert {:ok, response} = http_get("/blocks")

    assert Cbor.decode!(response.body) == blocks
    |> Enum.reverse
    |> Enum.map(&BlockView.as_map/1)
  end
end
