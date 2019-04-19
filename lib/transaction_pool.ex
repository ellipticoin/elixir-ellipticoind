defmodule TransactionPool do
  alias Node.Models.Transaction
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

  def add(transaction) do
    GenServer.call(__MODULE__, {:add, transaction})
  end

  def handle_call({:add, transaction}, {_pid, _reference}, state) do
    transaction_bytes =
      transaction
      |> Transaction.with_code()
      |> Cbor.encode()

    Redis.push("transactions::queued", [transaction_bytes])

    {:reply, {:ok, nil}, state}
  end
end
