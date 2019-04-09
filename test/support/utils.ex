defmodule Test.Utils do
  @host "http://localhost:4047"
  use Utils
  require Integer
  import Binary
  alias Crypto.Ed25519
  alias Node.Models.{Block, Contract}
  alias Node.Repo

  def set_balances(balances) do
    token_contract_address =
      Constants.system_address() <> (Constants.base_token_name() |> pad_trailing(32))

    for {address, balance} <- balances do
      Redis.set_binary(
        token_contract_address <> "balances" <> address,
        <<balance::little-size(64)>>
      )
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

  def test_wasm_path(name) do
      "test/support/wasm/src/#{name}/target/wasm32-unknown-unknown/debug/#{name}.wasm"
  end

  def poll_for_next_block() do
    best_block= Block.best() |> Repo.one()
    poll_for_next_block(best_block)
  end

  def poll_for_next_block(previous_block) do
    best_block= Block.best() |> Repo.one()

    cond do
      is_nil(previous_block) and is_nil(best_block) ->
        :timer.sleep(100)
        poll_for_next_block(best_block)
      is_nil(previous_block) and !is_nil(best_block) ->
        best_block
      best_block.number > previous_block.number ->
        best_block
      true ->
        :timer.sleep(100)
        poll_for_next_block(best_block)
    end
  end

  def parse_hex("0x" <> hex_data), do: parse_hex(hex_data)

  def parse_hex(hex_data) when Integer.is_odd(byte_size(hex_data)),
    do: parse_hex("0" <> hex_data)

  def parse_hex(hex_data), do: Base.decode16!(hex_data, case: :mixed)

  def checkout_repo() do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Node.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Node.Repo, {:shared, self()})
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

  def build_transaction(options \\ [], private_key) do
    defaults = %{
      address: <<0::256>>,
      contract_name: :BaseToken
    }

    sender = Ed25519.private_key_to_public_key(private_key)

    options
    |> Enum.into(defaults)
    |> Map.put(:sender, sender)
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
