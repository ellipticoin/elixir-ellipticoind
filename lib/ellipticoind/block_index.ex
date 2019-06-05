defmodule Ellipticoind.BlockIndex do
  def revert_to(block_number) do
    for key <- Redis.get_set("memory_keys") do
      Redis.remove_range_by_reverse_score(
        key,
        block_number,
        "+inf"
      )
    end
  end

  def get_latest(prefix, key) do
    case Redis.get_reverse_ordered_set_values(
           "#{prefix}:#{key}",
           "+inf",
           "-inf",
           0,
           1
         ) do
      [block_number] -> String.to_integer(block_number)
      _ -> nil
    end
  end

  def set_at_block(prefix, key, block_number) do
    Redis.add_to_sorted_set(
      "#{prefix}:#{key}",
      0,
      block_number
    )
  end
end
