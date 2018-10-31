defmodule TransactionPool do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    {:ok, redis} = Redix.start_link()

    {:ok,
     Map.merge(state, %{
       redis: redis,
       results: %{}
     })}
  end

  def add(transaction) when is_map(transaction) do
    add(Cbor.encode(transaction))
  end

  def add(transaction) do
    GenServer.call(__MODULE__, {:add, transaction})
  end

  def handle_call({:add, transaction}, {_pid, _reference}, state) do
    Redis.push("transactions::queued", transaction)

    {:reply, {:ok, nil}, state}
  end
end
