defmodule VM do
  use GenServer
  use Rustler, otp_app: :blacksmith, crate: :vm

  def run(_db, _env, _code, _rpc), do: exit(:nif_not_loaded)
  def transfer(_db, _sender, _recipeint, _amount), do: exit(:nif_not_loaded)
  def open_db(_backend, _options), do: exit(:nif_not_loaded)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    # {:ok, db} = VM.open_db(:rocksdb, "tmp/blockchain.db")
    {:ok, db} = VM.open_db(:redis, "redis://127.0.0.1/")
    {:ok, redis} = Redix.start_link()

    base_token_contract = File.read!(Application.get_env(:blacksmith, :base_contracts_path) <> "/base_token.wasm")

    {:ok, Map.merge(state, %{
      db: db,
      redis: redis,
      contracts: %{
        base_token: base_token_contract,
      }
    })}
  end

  def handle_call(
    %{
      rpc: rpc,
      sender: sender,
      nonce: _nonce,
    },
    _from,
    state=%{
      db: db,
      contracts: %{base_token: base_token_contract}
    }
  ) do
    env = %{
      sender: sender
    }

    case rpc do
      <<
        162,
        102,
        "params",
        130,
        88,
        32,
        recipient::binary-size(32),
        amount,
        102,
        "method",
        104,
        "transfer">> ->
          run_transfer(state, sender, recipient, amount)
      _ ->
        run_vm(state, db, env, base_token_contract, rpc)
    end
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

  def run_vm(state, db, env, base_token_contract, rpc) do
    case run(db, env, base_token_contract, rpc) do
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
