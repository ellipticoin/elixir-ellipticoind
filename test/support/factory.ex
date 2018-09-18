defmodule Blacksmith.Factory do
  use ExMachina.Ecto, repo: Blacksmith.Repo

  alias Models.{Block}

  def block_factory do
    %Block{
      parent_block: <<0::size(256)>>,
      number: 0,
      winner: <<0::size(256)>>,
      state_changes_hash: Crypto.hash(<<>>)
    }
  end
end
