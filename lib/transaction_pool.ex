defmodule TransactionPool do
  @forging_time_per_block 1_000
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    {:ok, db} = VM.open_db(:redis, "redis://127.0.0.1/")
    {:ok, redis} = Redix.start_link()
    {:ok, Map.merge(state, %{
      processes: %{},
      db: db,
      redis: redis,
      results: %{},
    })}
  end

  def add(transaction) do
    GenServer.call(__MODULE__, {:add, transaction})
  end

  def forge_block() do
    GenServer.cast(__MODULE__, {:forge_block})
  end

  def handle_cast(
    {:forge_block},
    state=%{
      redis: redis,
      results: results,
    }
  ) do

    results = forge_transactions(redis, results)

    Enum.each(results, fn {transaction, _result} ->
      transaction_forged(transaction)
    end)

    state = %{state | results: results}
    {:noreply, state}
  end

  def forge_transactions(redis, results) do
    {:ok, transaction} = Redis.lpop(redis, "transaction_pool")


    if transaction do
      decoded_transaction = Cbor.decode!(transaction)

      if Map.has_key?(decoded_transaction, :code) do
        {:ok, result} = VM.deploy(decoded_transaction)
      else
        {:ok, result} = VM.call(decoded_transaction)
      end

      results = Map.put(results, transaction, result)

      if within_forging_period?() do
        forge_transactions(redis, results)
      else
        results
      end
    else
      results
    end
  end

  def within_forging_period?() do
    Clock.time_since_last_block() < @forging_time_per_block
  end

  def handle_call(
    {:add, transaction},
    {pid, reference},
    state=%{
      redis: redis,
    }
  ) do
    Redis.rpush(redis,"transaction_pool", transaction)

    state = put_in(state, [:processes, transaction], pid)

    {:reply, {:ok, nil}, state}
  end

  def transaction_forged(transaction) do
    GenServer.cast(__MODULE__, {:forged, transaction})
  end

  def handle_cast(
    {
      :forged,
      transaction
    },
    state=%{
      redis: redis,
      results: results,
      processes: processes,
    }
  ) do
    pid = Map.get(processes, transaction)
    {result, results} = Map.pop(results, transaction)
    send(pid, {:transaction_forged, result})
    {:noreply, state}
  end

  def set_contract_code(redis, address, contract_name, contract_code) do
    key = address <> Helpers.pad_bytes_right(contract_name)

    Redis.set(redis, key, contract_code)
  end
end
