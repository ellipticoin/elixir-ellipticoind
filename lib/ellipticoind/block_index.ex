defmodule Ellipticoind.BlockIndex do
  def revert_to(prefix, block_number) do
    for key <- Redis.get_set("memory_keys") do
      index_of_key = Redis.get_hash_value("#{prefix}:#{key}_index", block_number)
      Redis.trim(
        "#{prefix}:#{key}",
        0,
        index_of_key
      )
    end
  end

  def get_latest(prefix, key) do
    case Redis.list_range(
           "#{prefix}:#{key}",
           -1,
           -1
         ) do
      [block_number] ->
             String.to_integer(block_number)
      _ -> nil
    end
  end

  def add(prefix, key, block_number) do
    Redis.push(
      "#{prefix}:#{key}",
      block_number
    )
    length = Redis.length("#{prefix}:#{key}")
    Redis.set_hash_value(
      "#{prefix}:#{key}_index",
      block_number,
      length - 1
    )
  end
end
