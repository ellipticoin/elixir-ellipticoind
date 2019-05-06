defmodule Test.Utils do
  @host "http://localhost:4047"
  use Utils
  require Integer
  import Binary
  alias Crypto.Ed25519
  alias Ellipticoind.Models.{Block, Contract, Transaction}
  alias Ellipticoind.Models.Block.TransactionProcessor
  alias Ellipticoind.Repo

  def set_balances(balances) do
    token_contract_address = <<0::256>> <> ("BaseToken" |> pad_trailing(32))

    for {address, balance} <- balances do
      key = token_contract_address <> <<0>> <> address
      memory_key = "memory:" <> key
      hash_key = <<0::little-size(64)>> <> key

      Redis.add_to_sorted_set(
        memory_key,
        0,
        hash_key
      )

      Redis.set_hash_value(
        "memory_hash",
        hash_key,
        <<balance::little-size(64)>>
      )

      # <<balance::little-size(64)>>  
      # Redis.set_binary(
      #   token_contract_address <> <<0>> <> address,
      #   <<balance::little-size(64)>>
      # )
    end
  end

  def get_balance(address) do
    key = <<0::256>> <> ("BaseToken" |> pad_trailing(32))
    memory_key = "memory:" <> key <> <<0>> <> address

    [hash_key] =
      Redis.get_reverse_ordered_set_values(
        memory_key,
        "+inf",
        "-inf",
        0,
        1
      )

    balance_bytes = Redis.get_hash_value("memory_hash", hash_key)

    # Not sure what causes this but sleepeing for 10ms prevents against the
    # following intermittent test error:
    #  `16:38:19.626 [error] Postgrex.Protocol (#PID<0.352.0>) disconnected: ** (DBConnection.ConnectionError) owner #PID<0.498.0> exited`
    :timer.sleep(10)

    if is_nil(balance_bytes) do
      0
    else
      :binary.decode_unsigned(balance_bytes, :little)
    end
  end

  def get_value(
        contract_name,
        key
      ) do
    memory = get_memory(contract_name, key)
    if memory == [] do
      nil
    else
      Cbor.decode!(memory)
    end
  end

  def get_memory(
        contract_name,
        key
      ) do
        memory_key = "memory:" <> <<0::256>> <> (Atom.to_string(contract_name) |> pad_trailing(32)) <> key
    case Redis.get_reverse_ordered_set_values(
        memory_key,
        "+inf",
        "-inf",
        0,
        1
    ) do
      [hash_key] -> Redis.get_hash_value("memory_hash", hash_key)
      _ -> []
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
    %Contract{
      address: <<0::256>>,
      name: contract_name,
      code: File.read!(test_wasm_path(Atom.to_string(contract_name)))
    }
    |> Repo.insert!()
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
      |> Repo.one()
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

  def get(options \\ []) do
    defaults = %{
      address: <<0::256>>,
      contract_name: :BaseToken
    }

    %{
      function: function,
      arguments: arguments,
      address: address,
      contract_name: contract_name
    } = Enum.into(options, defaults)

    address = Base.encode16(address, case: :lower)
    path = "/" <> Enum.join([address, contract_name], "/")

    query =
      Plug.Conn.Query.encode(%{
        function: function,
        arguments: Base.encode16(Cbor.encode(arguments))
      })

    {:ok, response} = http_get(path, query)
    Cbor.decode!(response.body)
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
      address: <<0::256>>,
      arguments: [],
      contract_name: :BaseToken,
      nonce: 0,
      sender: <<0>>,
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

  def http_get(path, query) do
    HTTPoison.get(@host <> path <> "?" <> query)
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

  def post_signed_block(block, private_key) do
    encoded_block = Block.as_binary(block)
    message = <<block.number::size(64)>> <> Crypto.hash(encoded_block)
    {:ok, signature} = Crypto.sign(message, private_key)

    HTTPoison.post(
      @host <> "/blocks",
      encoded_block,
      headers(signature)
    )
  end

  def put_signed(path, message, private_key) do
    signature =
      Crypto.sign(
        message,
        private_key
      )

    HTTPoison.put(
      @host <> path,
      message,
      headers(signature)
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
