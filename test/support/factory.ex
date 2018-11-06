defmodule Blacksmith.Factory do
  use ExMachina.Ecto, repo: Blacksmith.Repo

  alias Models.{Block}

  def block_factory do
    %Block{
      number: 0
      # winner: <<0::size(256)>>,
      # state_changes_hash: Crypto.hash(<<>>)
    }
  end
end
