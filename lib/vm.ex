defmodule VM do
  @system_address Constants.system_address()
  @base_token_name Constants.base_token_name()
  alias NativeContracts.BaseToken
  use GenServer
  use Rustler, otp_app: :blacksmith, crate: :vm

  def current_block_hash(_db), do: exit(:nif_not_loaded)
  def run(_db, _env, _contract_id, _address, _method, _params), do: exit(:nif_not_loaded)
  def open_db(_backend, _options), do: exit(:nif_not_loaded)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    {:ok, db} = VM.open_db(:redis, "redis://127.0.0.1/")
    {:ok, redis} = Redix.start_link()
    NetworkInitializer.run(redis)
    {:ok, Map.merge(state, %{
      db: db,
      redis: redis,
    })}
  end

  def deploy(deployment) do
    GenServer.call(VM, {:deploy, deployment})
  end


  def run_get(transaction) do
    GenServer.call(
      __MODULE__,
      {
        :run_get,
        transaction
      }
    )
  end

  def call(transaction) do
    GenServer.call(
      __MODULE__,
      {
        :call,
        transaction
      }
    )
  end

  def handle_call({:deploy, %{
    nonce: nonce,
    sender: sender,
    contract_name: contract_name,
    code: code,
    params: params,
  }}, from, state=%{}) do
    redis = Map.get(state, :redis)
    set_contract_code(
      redis,
      sender,
      Helpers.pad_bytes_right(contract_name),
      code
    )
    handle_call({
      :call, 
      %{
        method: :constructor,
        params: params,
        nonce: nonce,
        sender: sender,
        address: sender,
        contract_name: contract_name,
      }},
      from,
      state
    )
  end

  def handle_call({:run_get,
    transaction = %{
      method: method,
      params: params,
      address: address,
      contract_name: contract_name,
    }},
    _from,
    state=%{
      db: db,
    }
  ) do
    env = %{
      address: address,
      contract_id: Helpers.pad_bytes_right(contract_name),
    }

    run_vm(
      state,
      db,
      env,
      address,
      Helpers.pad_bytes_right(contract_name),
      method,
      params
    )
  end

  def handle_call({
    :call,
    %{
      method: method,
      params: params,
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

    case {address, contract_name, method, params} do
      {address, @base_token_name, :transfer, [recipient, amount]} ->
        BaseToken.transfer(state, env, recipient, amount)
      _ ->
        run_vm(
          state,
          db,
          env,
          address,
          Helpers.pad_bytes_right(contract_name),
          method,
          params
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

  def run_vm(state, db, env, address, contract_id, method, params) do
    case run(db, env, address, contract_id, method, params) do
      {:ok, result} ->
        format_result(state, result)
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

  def format_result(state, <<>>) do
    {:reply, {:ok, ""}, state}
  end
end
