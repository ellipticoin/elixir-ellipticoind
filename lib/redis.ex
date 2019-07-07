defmodule Redis do
  import Utils
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(_args) do
    connection_url = Application.fetch_env!(:ellipticoind, :redis_url)
    Redix.start_link(connection_url)
  end

  def fetch(key, default \\ nil) do
    case GenServer.call(Redis, {:get, key}) do
      {:ok, nil} -> {:ok, default}
      result -> result
    end
  end

  def reset() do
    GenServer.cast(Redis, :reset)
  end

  def delete(key) do
    GenServer.cast(Redis, {:delete, key})
  end

  def publish(channel, value) when is_list(value) do
    value =
      value
      |> Enum.map(fn item -> "#{item}" end)
      |> Enum.join(" ")

    publish(channel, value)
  end

  def publish(channel, value) do
    GenServer.cast(Redis, {:publish, channel, value})
  end

  def set(key, value) do
    GenServer.call(Redis, {:set, key, value})
  end

  def add_to_sorted_set(key, score, value) do
    GenServer.call(Redis, {:add_to_sorted_set, key, score, value})
  end

  def get_reverse_ordered_set_values(key, min, max, offset, count) do
    GenServer.call(Redis, {:get_reverse_ordered_set_values, key, min, max, offset, count})
  end

  def list_range(key, min, max) do
    GenServer.call(Redis, {:list_range, key, min, max})
  end

  def length(key) do
    GenServer.call(Redis, {:length, key})
  end

  def set_hash_value(hash, key, value) do
    GenServer.call(Redis, {:set_hash_value, hash, key, value})
  end

  def remove_range_by_reverse_score(key, min, max) do
    GenServer.call(Redis, {:remove_range_by_reverse_score, key, min, max})
  end

  def trim(key, min, max) do
    GenServer.call(Redis, {:trim, key, min, max})
  end

  def get_hash_value(hash, key) do
    GenServer.call(Redis, {:get_hash_value, hash, key})
  end

  def set_map(key, value) do
    GenServer.cast(Redis, {:set_map, key, value})
  end

  def get_map(key, struct \\ nil) do
    GenServer.call(Redis, {:get_map, key, struct})
  end

  def get(key) do
    GenServer.call(Redis, {:get, key})
  end

  def push(key, value) do
    GenServer.call(Redis, {:push, key, value})
  end

  def pop(key) do
    GenServer.call(Redis, {:pop, key})
  end

  def get_list(key) do
    GenServer.call(Redis, {:get_list, key})
  end

  def get_set(key) do
    GenServer.call(Redis, {:get_set, key})
  end

  def add_set(key, value) do
    GenServer.call(Redis, {:add_set, key, value})
  end

  def handle_cast(:reset, redis) do
    Redix.command(redis, [
      "FLUSHALL"
    ])

    {:noreply, redis}
  end

  def handle_cast({:set_map, key, value}, redis) do
    value =
      if Map.has_key?(value, :__struct__) do
        Map.from_struct(value)
      else
        value
      end

    keys_and_values =
      Enum.flat_map(value, fn {k, v} ->
        if is_number(v) do
          [k, :binary.encode_unsigned(v)]
        else
          [k, v]
        end
      end)

    Redix.command(
      redis,
      [
        "HSET",
        key
      ] ++ keys_and_values
    )

    {:noreply, redis}
  end

  def handle_cast({:publish, channel, value}, redis) do
    Redix.command(redis, [
      "PUBLISH",
      channel,
      value
    ])

    {:noreply, redis}
  end

  def handle_cast({:delete, key}, redis) do
    Redix.command(redis, [
      "DEL",
      key
    ])

    {:noreply, redis}
  end

  def handle_call({:add_to_sorted_set, key, score, value}, _from, redis) do
    Redix.command(redis, [
      "ZADD",
      key,
      score,
      value
    ])

    {:reply, nil, redis}
  end

  def handle_call({:trim, key, min, max}, _from, redis) do
    {:ok, value} =
      Redix.command(redis, [
        "LTRIM",
        key,
        min,
        max,
      ])

    {:reply, value, redis}
  end

  def handle_call({:remove_range_by_reverse_score, key, min, max}, _from, redis) do
    {:ok, value} =
      Redix.command(redis, [
        "ZREMRANGEBYSCORE",
        key,
        "(#{min}",
        max
      ])

    {:reply, value, redis}
  end

  def handle_call({:get_reverse_ordered_set_values, key, min, max, offset, count}, _from, redis) do
    {:ok, value} =
      Redix.command(redis, [
        "ZREVRANGEBYSCORE",
        key,
        min,
        max,
        "LIMIT",
        offset,
        count
      ])

    {:reply, value, redis}
  end

  def handle_call({:list_range, key, min, max}, _from, redis) do
    {:ok, value} =
      Redix.command(redis, [
        "LRANGE",
        key,
        "#{min}",
        "#{max}",
      ])

    {:reply, value, redis}
  end

  def handle_call({:length, key}, _from, redis) do
    {:ok, value} =
      Redix.command(redis, [
        "LLEN",
        key,
      ])

    {:reply, value, redis}
  end

  def handle_call({:get_hash_value, hash, key}, _from, redis) do
    {:ok, value} =
      Redix.command(redis, [
        "HGET",
        hash,
        key
      ])

    {:reply, value, redis}
  end

  def handle_call({:set_hash_value, hash, key, value}, _from, redis) do
    Redix.command(redis, [
      "HSET",
      hash,
      key,
      value
    ])

    {:reply, nil, redis}
  end

  def handle_call({:set, key, value}, _from, redis) do
    Redix.command(redis, [
      "SET",
      key,
      value
    ])

    {:reply, nil, redis}
  end

  def handle_call({:push, key, value}, _from, redis) do
    Redix.command(
      redis,
      List.flatten([
        "RPUSH",
        key,
        value
      ])
    )

    {:reply, nil, redis}
  end

  def handle_call({:get_map, key, struct}, _from, redis) do
    value =
      Redix.command(redis, [
        "HGETALL",
        key
      ])
      |> ok
      |> Enum.chunk_every(2)
      |> Map.new(fn [k, v] ->
        if is_number(Map.get(struct(struct), String.to_atom(k))) do
          {String.to_atom(k), :binary.decode_unsigned(v)}
        else
          {String.to_atom(k), v}
        end
      end)

    {:reply, value, redis}
  end

  def handle_call({:get, key}, _from, redis) do
    value =
      Redix.command(redis, [
        "GET",
        key
      ])

    {:reply, value, redis}
  end

  def handle_call({:get_list, key}, _from, redis) do
    value =
      Redix.command(redis, [
        "LRANGE",
        key,
        0,
        -1
      ])

    {:reply, value, redis}
  end

  def handle_call({:add_set, key, value}, _from, redis) do
    {:ok, value} =
      Redix.command(redis, [
        "SADD",
        key,
        value
      ])

    {:reply, value, redis}
  end

  def handle_call({:get_set, key}, _from, redis) do
    {:ok, value} =
      Redix.command(redis, [
        "SMEMBERS",
        key
      ])

    {:reply, value, redis}
  end

  def handle_call({:pop, key}, _from, redis) do
    value =
      Redix.command(redis, [
        "LPOP",
        key
      ])

    {:reply, value, redis}
  end
end
