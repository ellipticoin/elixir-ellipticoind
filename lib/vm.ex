defmodule VM do
  @system_address Constants.system_address()
  @base_token_name Constants.base_token_name()
  alias NativeContracts.BaseToken
  use GenServer
  #use Rustler, otp_app: :blacksmith, crate: :vm

  def current_block_hash(_db), do: exit(:nif_not_loaded)
  def run(_db, _transaction), do: exit(:nif_not_loaded)
  def start_forging(_db), do: exit(:nif_not_loaded)
  def open_db(_backend, _options), do: exit(:nif_not_loaded)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    # {:ok, db} = VM.open_db(:redis, "redis://127.0.0.1/")
    # {:ok, redis} = Redix.start_link()
    # {:ok, pubsub} = Redix.PubSub.start_link()
    # Blockchain.initialize()
    # channel = "transactions"
    # Redix.PubSub.subscribe(pubsub, channel, self())
    # receive do
    #   {:redix_pubsub, ^pubsub, :subscribed, %{channel: channel}} -> :ok
    # end
    #
    # {:ok,
    #  Map.merge(state, %{
    #    db: db,
    #    pubsub: pubsub,
    #    redis: redis
    #  })}
    {:ok, {}}
  end

  def start_forging() do
    GenServer.cast(__MODULE__, {:start_forging})
  end

  def get(transaction) when is_map(transaction) do
    get(Cbor.encode(transaction))
  end

  def get(transaction) do
    GenServer.call(__MODULE__, {:get, transaction})
  end

  def handle_call({:get, transaction}, _from, state = %{db: db}) do
    run_vm(state, db, transaction)
  end

  def handle_cast({:start_forging}, state = %{db: db}) do
    start_forging(db)

    {:noreply, state}
  end

  def handle_call({:wait_for_transaction, sender, nonce}, _from, state = %{pubsub: pubsub}) do
    result = receive do
      {:redix_pubsub, ^pubsub, :message, %{channel: channel, payload: result}} -> result
    end

    {:reply, {:ok, result}, state}
  end

  def set_contract_code(redis, address, contract_name, contract_code) do
    key = address <> Helpers.pad_bytes_right(contract_name)

    redis
    |> set_state(key, contract_code)
  end

  def set_state(redis, key, value) do
    Redix.command(redis, [
      "SET",
      key,
      value
    ])
  end

  def run_vm(state, db, transaction) do
    case run(db, transaction) do
      {:ok, result} ->
        format_result(state, result)

      _ ->
        {:reply, {:error, 0, "VM panic"}, state}
    end
  end

  def format_result(state, <<
        error_binary::binary-size(4),
        result::binary
      >>) do
    error_code = :binary.decode_unsigned(error_binary, :little)

    if error_code == 0 do
      {:reply, {:ok, result}, state}
    else
      {:reply, {:error, error_code, Atom.to_string(Cbor.decode(result))}, state}
    end
  end

  def format_result(state, <<>>) do
    {:reply, {:ok, ""}, state}
  end
end
