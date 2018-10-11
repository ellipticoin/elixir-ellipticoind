defmodule TransactionPool do
  @channel "transactions"
  @db Db.Redis
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    {:ok, pubsub} = Redix.PubSub.start_link()
    {:ok, redis} = Redix.start_link()
    Redix.PubSub.subscribe(pubsub, @channel, self())

    {:ok,
     Map.merge(state, %{
       pubsub: pubsub,
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
        IO.inspect("got it")
        {return_code, result}

      other ->
        IO.inspect(other)
    end
  end

  def subscribe(sender, nonce, pid) do
    GenServer.cast(__MODULE__, {:subscribe, sender, nonce, pid})
  end

  def handle_info({:redix_pubsub, pid, :subscribed, %{channel: @channel}}, state) do
    {:noreply, state}
  end

  def handle_cast({:subscribe, sender, nonce, pid}, state = %{pubsub: pubsub}) do
    sender_and_nonce = sender <> <<nonce::little-unsigned-64>>
    state = put_in(state, [:subscribers, sender_and_nonce], pid)
    {:noreply, state}
  end

  def handle_info(
        {:redix_pubsub, pubsub, :message, %{channel: @channel, payload: payload}},
        state
      ) do
    <<
      sender_and_nonce::binary-size(40),
      output::binary
    >> = payload

    pid = get_in(state, [:subscribers, sender_and_nonce])
    send(pid, {:transaction, :done, output})
    {:noreply, state}
  end

  def handle_call(
        {:add, transaction},
        {pid, _reference},
        state = %{
          redis: redis
        }
      ) do
    @db.push("transactions::queued", transaction)

    {:reply, {:ok, nil}, state}
  end

  def set_contract_code(redis, address, contract_name, contract_code) do
    key = address <> Helpers.pad_bytes_right(contract_name)

    Redis.set(redis, key, contract_code)
  end
end
