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
       results: %{},
       auto_forge: false,
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


  def handle_call(
        {:add, transaction},
        {_pid, _reference},
        state = %{
          redis: _redis,
          auto_forge: auto_forge,
        }
      ) do
    Redis.push("transactions::queued", transaction)

    if auto_forge do
      TransactionProccessor.proccess_transactions(1)
    end

    {:reply, {:ok, nil}, state}
  end

  def enable_auto_forging() do
    GenServer.cast(__MODULE__, {:enable_auto_forging})
  end

  def disable_auto_forging() do
    GenServer.cast(__MODULE__, {:disable_auto_forging})
  end

  def handle_cast({:enable_auto_forging}, state) do
    {:noreply, %{state | auto_forge: true}}
  end

  def handle_cast({:disable_auto_forging}, state) do
    {:noreply, %{state | auto_forge: false}}
  end
end
