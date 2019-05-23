defmodule Ellipticoind.BlockIndex do
  def get_at_block(prefix, key, block_number) do
    case Redis.get_reverse_ordered_set_values(
           "#{prefix}:#{key}",
           "+inf",
           "-inf",
           block_number,
           1
         ) do
      [hash_key] -> hash_key
      _ -> nil
    end
  end

  def set_at_block(prefix, key, block_number) do
    Redis.add_to_sorted_set(
      "#{prefix}:#{key}",
      0,
      <<block_number::little-size(64)>> <> key
    )
  end
end
