defmodule Blacksmith.Factory do
  use ExMachina.Ecto, repo: Blacksmith.Repo

  alias Blacksmith.Models.Block

  def block_factory do
    %Block{
      number: 0,
      winner: <<0::size(256)>>,
      ethereum_block_hash: <<0::size(256)>>,
      ethereum_block_number: 0,
      ethereum_difficulty: 0,
      changeset_hash: Crypto.hash(<<>>)
    }
  end
end
