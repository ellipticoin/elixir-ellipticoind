defmodule RocksDB do
  import Utils
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(_args) do
    {:ok, db} = Rox.open(Config.rocksdb_path(), create_if_missing: true)
  end

  def put(key, value) do
    GenServer.call(RocksDB, {:put, key, value})
  end

  def get(key) do
    GenServer.call(RocksDB, {:get, key})
  end

  def handle_call({:put, key, value}, _from, rocksdb) do
    Rox.put(rocksdb,
      key,
      value
    )

    {:reply, nil, rocksdb}
  end

  def handle_call({:get, key, value}, _from, rocksdb) do
    value = Rox.get(rocksdb, key)

    {:reply, value, rocksdb}
  end
end
