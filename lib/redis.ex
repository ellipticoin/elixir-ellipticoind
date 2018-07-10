defmodule Redis do
  def flushall(redis) do
    Redix.command(redis, [
      "FLUSHALL",
    ])
  end

  def set(redis, key, value) do
    Redix.command(redis, [
      "SET",
      key,
      value
    ])
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
      key,
    ])
  end

  def llen(redis, key) do
    Redix.command(redis, [
      "LLEN",
      key,
    ])
  end
end
