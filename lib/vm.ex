defmodule VM do
  use GenServer
  use Rustler, otp_app: :blacksmith, crate: :vm

  def run(_db, _env, _contract_id, _address, _rpc), do: exit(:nif_not_loaded)
  def open_db(_backend, _options), do: exit(:nif_not_loaded)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    {:ok, db} = VM.open_db(:redis, "redis://127.0.0.1/")
    {:ok, redis} = Redix.start_link()
    set_contract_code(
      redis,
      Constants.system_address(),
      Constants.base_token_name(),
      Constants.base_token_code()
    )

    {:ok, Map.merge(state, %{
      db: db,
      redis: redis,
    })}
  end

  def handle_call({:deploy, %{
    sender: sender,
    address: address,
    contract_name: contract_name,
    code: code,
  }}, _from, state=%{}) do
    redis = Map.get(state, :redis)
    set_contract_code(
      redis,
      address,
      Helpers.pad_bytes_right(contract_name),
      code
    )
    {:reply, :ok, state}
  end

  def handle_call({:call,
    %{
      rpc: rpc,
      sender: sender,
      nonce: _nonce,
      address: address,
      contract_name: contract_name,
    }},
    _from,
    state=%{
      db: db,
    }
  ) do
    env = %{
      sender: sender,
      address: address,
      contract_id: Helpers.pad_bytes_right(contract_name),
    }

    case rpc do
      <<
        130,          # Start CBOR Array length 2
        104,          # Start CBOR String length 8
        "transfer",
        130,          # Start CBOR Array length 2
        88,           # Start CBOR Binary size 32
        32,
        recipient::binary-size(32),
        amount>> ->
          run_transfer(state, sender, recipient, amount)
      _ ->
        run_vm(
          state,
          db,
          env,
          address,
          Helpers.pad_bytes_right(contract_name),
          rpc
        )
    end
  end

  def set_contract_code(redis, address, contract_name, contract_code) do
    key = address <> Helpers.pad_bytes_right(contract_name)

    redis |>
      set_state(key, contract_code)
  end

  def set_state(redis, key, value) do
    Redix.command(redis, [
      "SET",
      key,
      value
    ])
  end

  def run_transfer(state, sender, recipient, amount) do
    redis = Map.get(state, :redis)
    Redix.command(redis, [
      "BITFIELD",
      recipient,
      "INCRBY",
      "i64",
      0,
      1
    ])

    Redix.command(redis, [
      "BITFIELD",
      sender,
      "INCRBY",
      "i64",
      0,
      -1
    ])
    {:reply, {:ok, ""}, state}

  end

  def run_vm(state, db, env, address, contract_id, rpc) do
    case run(db, env, address, contract_id, rpc) do
      {:ok, result} -> format_result(state, result)
      _ -> {:reply, {:error, 0, "VM panic"}, state}
    end
  end

  def format_result(state, <<
        error_binary::binary-size(4),
        result::binary,
        >>) do
        error_code = :binary.decode_unsigned(error_binary, :little)

        if error_code == 0 do
          {:reply, {:ok, result}, state}
        else
          {:reply, {:error, error_code, Atom.to_string(Cbor.decode(result))}, state}
        end
  end
end
