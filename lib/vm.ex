defmodule VM do
  use GenServer
  use Rustler, otp_app: :blacksmith, crate: :vm

  def run(_db, _env, _code, _rpc), do: exit(:nif_not_loaded)
  def open_db(_arg1), do: exit(:nif_not_loaded)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    {:ok, db} = VM.open_db("tmp/blockchain.db")

    base_token_contract = File.read!(Application.get_env(:blacksmith, :base_contracts_path) <> "/base_token.wasm")

    {:ok, Map.merge(state, %{
      db: db,
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

    case run(db, env, base_token_contract, rpc) do
      {:ok, <<
        error_binary::binary-size(4),
        result::binary,
        >>} ->
        error_code = :binary.decode_unsigned(error_binary, :little)

        if error_code == 0 do
          {:reply, {:ok, result}, state}
        else
          {:reply, {:error, error_code, Atom.to_string(Cbor.decode(result))}, state}
        end
      _ -> {:reply, {:error, 0, "VM panic"}, state}
    end
  end
end
