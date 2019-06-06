defmodule RocksDB do
  use GenServer
  @crate "rocksdb"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(_init_arg) do
    port =
      Port.open({:spawn_executable, path_to_executable()},
        args: [
          Config.rocksdb_path()
        ]
      )

    {:ok, port}
  end

  def get(block_number, key) do
    GenServer.call(__MODULE__, {:get, block_number, key})
  end

  def put(block_number, key, value) do
    GenServer.call(__MODULE__, {:put, block_number, key, value})
  end

  def handle_call({:get, block_number, key}, _from, port) do
    key_encoded = (<<block_number::little-size(64)>> <> key) |> Base.encode64()
    command = "get " <> key_encoded <> "\n"
    send(port, {self(), {:command, command}})

    value =
      receive do
        {_port, {:data, message}} ->
          message
          |> List.to_string()
          |> String.trim("\n")
          |> Base.decode64!()
      end

    {:reply, value, port}
  end

  def handle_call({:put, block_number, key, value}, _from, port) do
    key_encoded = (<<block_number::little-size(64)>> <> key) |> Base.encode64()
    value_encoded = value |> Base.encode64()
    command = "put " <> key_encoded <> " " <> value_encoded <> "\n"
    send(port, {self(), {:command, command}})

    receive do
      {_port, {:data, 'ok\n'}} -> nil
    end

    :timer.sleep(1000)

    {:reply, nil, port}
  end

  def handle_info({_port, {:data, message}}, port) do
    {:noreply, port}
  end

  def path_to_executable(), do: Application.app_dir(:ellipticoind, ["priv", "native", @crate])
end
