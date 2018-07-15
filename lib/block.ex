defmodule Block do
  @hash_size Crypto.hash_size()

  defstruct parent_block: <<0::size(256)>>,
        number: 0,
        winner: <<0::size(256)>>,
        state_changes_hash: Crypto.hash!(<<>>)

  def serialize(%{
    parent_block: parent_block,
    number: number,
    winner: winner,
    state_changes_hash: state_changes_hash,
  }) do
    parent_block <> <<number::size(256)>> <> winner <> state_changes_hash
  end

  def hash(block), do:
    Crypto.hash!(serialize(block))
end
