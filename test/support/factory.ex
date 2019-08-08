defmodule Ellipticoind.Factory do
  use ExMachina.Ecto, repo: Ellipticoind.Repo

  alias Ellipticoind.Models.Block

  def block_factory do
    %Block{
      number: 0,
      winner: <<0::size(256)>>
    }
  end
end
