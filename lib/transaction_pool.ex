defmodule TransactionPool do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    {:ok, redis} = Redix.start_link()

    {:ok,
     Map.merge(state, %{
       subscribers: %{},
       processes: %{},
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

  def wait_for_transaction(sender, nonce) do
    TransactionPool.subscribe(sender, nonce, self())

    receive do
      {:transaction, :done, <<return_code::size(32), result::binary>>} ->
        {return_code, result}
    end
  end

  def subscribe(sender, nonce, pid) do
    GenServer.cast(__MODULE__, {:subscribe, sender, nonce, pid})
  end

  def handle_call(
        {:add, transaction},
        {_pid, _reference},
        state = %{
          redis: _redis
        }
      ) do
    Redis.push("transactions::queued", transaction)

    {:reply, {:ok, nil}, state}
  end
end
