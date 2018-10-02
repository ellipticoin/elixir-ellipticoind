defmodule Redis do
  import Utils

  def flushall(redis) do
    Redix.command(redis, [
      "FLUSHALL"
    ])
  end

  def get(redis, key) do
    Redix.command(redis, [
      "GET",
      key
    ])
  end

  def del(redis, key) do
    Redix.command(redis, [
      "DEL",
      key
    ])
  end

  def set(redis, key, value) do
    Redix.command(redis, [
      "SET",
      key,
      value
    ])
  end

  def hset(redis, key, hash) do
    Redix.command(
      redis,
      [
        "HSET",
        key
      ] ++ Enum.flat_map(hash, fn {k, v} -> [k, v] end)
    )
  end

  def hgetall(redis, key) do
    Redix.command(redis, [
      "HGETALL",
      key
    ])
    |> ok
    |> Enum.chunk_every(2)
    |> Map.new(fn [k, v] ->
      {String.to_atom(k), v}
    end)
  end

  def rpush(redis, key, value) do
    Redix.command(redis, [
      "RPUSH",
      key,
      value
    ])
  end

  def lpop(redis, key) do
    Redix.command(redis, [
      "LPOP",
      key
    ])
  end

  def llen(redis, key) do
    Redix.command(redis, [
      "LLEN",
      key
    ])
  end

  def lrange(redis, key, start, stop) do
    Redix.command(redis, [
      "LRANGE",
      key,
      start,
      stop
    ])
  end
end
