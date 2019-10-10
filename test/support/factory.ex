defmodule Ellipticoind.Factory do
  use ExMachina.Ecto, repo: Ellipticoind.Repo

  alias Ellipticoind.Models.Block

  def block_changeset_factory do
    Block.changeset(%Block{}, %{
      number: sequence(:number, &(&1)),
      hash: sequence(:hash, &(<<&1::256>>)),
      proof_of_work_value: 1,
    })
  end
end
