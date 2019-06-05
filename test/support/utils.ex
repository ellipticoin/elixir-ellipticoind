defmodule Test.Utils do
  @host "http://localhost:4047"
  use Utils
  require Integer
  alias Crypto.Ed25519
  alias Ellipticoind.Models.{Block, Contract, Transaction}
  alias Ellipticoind.Models.Block.TransactionProcessor
  alias Ellipticoind.Storage
  alias Ellipticoind.{Memory, Repo}

  def set_balances(balances) do
    for {address, balance} <- balances do
      Memory.set(
        <<0::256>>,
        :BaseToken,
        0,
        <<0>> <> address,
        <<balance::little-size(64)>>
      )
    end
  end

  def get_balance(address) do
    balance_bytes = Memory.get(<<0::256>>, :BaseToken, <<0>> <> address)

    # Not sure what causes this but sleepeing for 10ms prevents against the
    # following intermittent test error:
    #  `16:38:19.626 [error] Postgrex.Protocol (#PID<0.352.0>) disconnected: ** (DBConnection.ConnectionError) owner #PID<0.498.0> exited`
    :timer.sleep(10)

    if balance_bytes == [] do
      0
    else
      :binary.decode_unsigned(balance_bytes, :little)
    end
  end

  def insert_contracts do
    %Contract{
      address: <<0::256>>,
      name: :BaseToken,
      code: Contract.base_contract_code(:BaseToken)
    }
    |> Repo.insert!()
  end

  def insert_test_contract(contract_name) do
    Storage.set(0, <<0::256>>, contract_name, "_code", File.read!(test_wasm_path(Atom.to_string(contract_name))))
  end

  def post_transaction(transaction) do
    build_transaction(transaction)
    |> Transaction.post()
  end

  def run_transaction(transaction, block_params \\ %{}) do
    %{
      return_code: return_code,
      return_value: return_value
    } =
      %Block{
        transactions: [build_transaction(transaction)]
      }
      |> Map.merge(block_params)
      |> TransactionProcessor.process()
      |> Map.get(:transactions)
      |> List.first()
      |> Map.take([
        :return_code,
        :return_value
      ])

    if return_code == 0 do
      {:ok, return_value}
    else
      {:error, return_value}
    end
  end

  def test_wasm_path(name) do
    "test/support/wasm/#{name}.wasm"
  end

  def poll_for_block(block_number) do
    best_block =
      Block.best()
      |> Repo.preload(:transactions)

    if best_block && best_block.number == block_number do
      best_block
    else
      poll_for_block(block_number)
    end
  end

  def parse_hex("0x" <> hex_data), do: parse_hex(hex_data)

  def parse_hex(hex_data) when Integer.is_odd(byte_size(hex_data)),
    do: parse_hex("0" <> hex_data)

  def parse_hex(hex_data), do: Base.decode16!(hex_data, case: :mixed)

  def checkout_repo() do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Ellipticoind.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Ellipticoind.Repo, {:shared, self()})
  end

  def read_test_wasm(file_name) do
    Path.join([test_support_dir(), "wasm", file_name])
    |> File.read!()
  end

  def test_support_dir() do
    Path.join([File.cwd!(), "test", "support"])
  end

  def post(transaction, private_key) do
    http_post_signed(
      "/transactions",
      Cbor.encode(build_transaction(transaction, private_key)),
      private_key
    )
  end

  def build_signed_transaction(options, private_key) do
    transaction = build_transaction(options, private_key)
    signature = Crypto.sign(transaction, private_key)
    Map.put(transaction, :signature, signature)
  end

  def build_transaction(transaction, private_key \\ nil) do
    defaults = %{
      contract_address: <<0::256>>,
      contract_name: :BaseToken,
      arguments: [],
      nonce: 0,
      sender: <<0>>
    }

    transaction = Map.merge(defaults, transaction)

    if private_key do
      sender = Ed25519.private_key_to_public_key(private_key)

      transaction
      |> Map.put(:sender, sender)
    else
      transaction
    end
  end

  def http_get(path) do
    HTTPoison.get(@host <> path)
  end

  def join_network(port) do
    HTTPoison.post(
      @host <> "/peers",
      Cbor.encode(%{
        url: "http://localhost:#{port}"
      }),
      headers()
    )
  end

  def http_post_signed(path, message, private_key) do
    signature = Crypto.sign(message, private_key)

    HTTPoison.post(
      @host <> path,
      message,
      headers(signature),
      timeout: 50_000,
      recv_timeout: 50_000
    )
  end

  def headers(signature \\ nil) do
    if signature do
      %{
        "Content-Type": "application/cbor",
        Authorization: "Signature " <> Base.encode16(signature, case: :lower)
      }
    else
      %{
        "Content-Type": "application/cbor"
      }
    end
  end
end
