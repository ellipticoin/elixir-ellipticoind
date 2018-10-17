defmodule Redis do
  @behaviour DbBehaviour
  import Utils
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(_args) do
    {:ok, redis} = Redix.start_link()
    {:ok, redis}
  end

  def get_binary(key) do
    GenServer.call(Redis, {:get_binary, key})
  end

  def reset() do
    GenServer.cast(Redis, :reset)
  end

  def delete(key) do
    GenServer.cast(Redis, {:delete, key})
  end

  def set_binary(key, value) do
    GenServer.cast(Redis, {:set_binary, key, value})
  end

  def set_map(key, value) do
    GenServer.cast(Redis, {:set_map, key, value})
  end

  def get_map(key, struct \\ nil) do
    GenServer.call(Redis, {:get_map, key, struct})
  end

  def push(key, value) do
    GenServer.cast(Redis, {:push, key, value})
  end

  def pop(key) do
    GenServer.call(Redis, {:pop, key})
  end

  def get_list(key) do
    GenServer.call(Redis, {:get_list, key})
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

  def handle_cast({:delete, key}, redis) do
    Redix.command(redis, [
      "DEL",
      key
    ])

    {:noreply, redis}
  end

  def handle_cast({:set_binary, key, value}, redis) do
    Redix.command(redis, [
      "SET",
      key,
      value
    ])

    {:noreply, redis}
  end

  def handle_cast({:push, key, value}, redis) do
    Redix.command(redis, [
      "RPUSH",
      key,
      value
    ])

    {:noreply, redis}
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

  def handle_call({:pop, key}, _from, redis) do
    value =
      Redix.command(redis, [
        "LPOP",
        key
      ])

    {:reply, value, redis}
  end

  def handle_call({:get_binary, key}, _from, redis) do
    value =
      Redix.command(redis, [
        "GET",
        key
      ])

    {:reply, value, redis}
  end
end
