defmodule Block do
  @hash_size Crypto.hash_size()

  defstruct parent_block: <<0::size(256)>>,
            number: 0,
            winner: <<0::size(256)>>,
            state_changes_hash: Crypto.hash(<<>>)

  def to_binary(%{
        parent_block: parent_block,
        number: number,
        winner: winner,
        state_changes_hash: state_changes_hash
      }) do
    parent_block <> <<number::size(256)>> <> winner <> state_changes_hash
  end

  def to_json(block) do
    block
    |> Map.from_struct()
    |> Enum.map(fn {key, value} ->
      if is_binary(value) do
        {key, Base.encode16(value, case: :lower)}
      else
        {key, value}
      end
    end)
    |> Enum.into(%{})
    |> Poison.encode!()
  end

  def to_binary(%{
        parent_block: parent_block,
        number: number,
        winner: winner,
        state_changes_hash: state_changes_hash
      }) do
    parent_block <> <<number::size(256)>> <> winner <> state_changes_hash
  end

  def from_map(%{
        parent_block: parent_block,
        number: number,
        winner: winner,
        state_changes_hash: state_changes_hash
      }) do
    {number, _} = Integer.parse(number)

    %__MODULE__{
      parent_block: parent_block,
      number: number,
      winner: winner,
      state_changes_hash: state_changes_hash
    }
  end

  def hash(block), do: Crypto.hash(to_binary(block))
end
