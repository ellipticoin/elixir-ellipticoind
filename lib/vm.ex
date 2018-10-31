defmodule VM do
  use GenServer
  use Rustler, otp_app: :blacksmith, crate: :vm_nif

  def current_block_hash(_redis_url), do: exit(:nif_not_loaded)
  def run(_redis_url, _transaction), do: exit(:nif_not_loaded)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    {:ok,
     Map.merge(state, %{
       redis_url: "redis://127.0.0.1/"
     })}
  end

  def get(transaction) when is_map(transaction) do
    get(Cbor.encode(transaction))
  end

  def get(transaction) do
    GenServer.call(__MODULE__, {:get, transaction})
  end

  def handle_call({:get, transaction}, _from, state = %{redis_url: redis_url}) do
    run_vm(state, redis_url, transaction)
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

  def run_vm(state, redis_url, transaction) do
    case run(redis_url, transaction) do
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
