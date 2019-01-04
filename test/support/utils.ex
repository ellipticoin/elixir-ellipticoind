defmodule Test.Utils do
  @host "http://localhost:4047"
  @default_gas_limit 6_721_975
  @default_gas_price 20_000_000_000
  use Utils
  require Integer
  import Binary
  import Ethereum.Helpers
  alias Crypto.Ed25519
  alias Crypto.RSA
  alias Blacksmith.Models.{Block, Contract}
  alias Blacksmith.Repo
  alias Ethereum.Contracts.{EllipticoinStakingContract, TestnetToken}

  def set_balances(balances) do
    token_contract_address =
      Constants.system_address() <> (Constants.base_token_name() |> pad_trailing(32))

    for {address, balance} <- balances do
      Redis.set_binary(token_contract_address <> address, <<balance::little-size(64)>>)
    end
  end

  def insert_tesetnet_contracts do
    %Contract{
      address: <<0::256>>,
      name: "BaseToken",
      code: Contract.base_contract_code(:BaseToken)
    }
    |> Repo.insert!()
  end

  def parse_hex("0x" <> hex_data), do: parse_hex(hex_data)

  def parse_hex(hex_data) when Integer.is_odd(byte_size(hex_data)),
    do: parse_hex("0" <> hex_data)

  def parse_hex(hex_data), do: Base.decode16!(hex_data, case: :mixed)

  def checkout_repo() do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Blacksmith.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Blacksmith.Repo, {:shared, self()})
  end

  def fund_staking_contract() do
    starting_stake = 100
    staking_contract_address = EllipticoinStakingContract.address()

    Enum.each(Enum.take(ExW3.accounts(), 3), fn account ->
      TestnetToken.mint(account, starting_stake)
      TestnetToken.approve(staking_contract_address, starting_stake, account)
      EllipticoinStakingContract.deposit(starting_stake, account)
    end)
  end

  def set_public_moduli() do
    {:ok, body} = File.read("staking_contract/test/support/test_private_keys.txt")

    rsa_public_keys =
      body
      |> String.trim("\n")
      |> String.split("\n\n")
      |> Enum.map(&RSA.parse_pem/1)
      |> Enum.map(&RSA.private_key_to_public_key/1)

    testnet_private_keys = Application.get_env(:blacksmith, :testnet_private_keys)

    Enum.take(testnet_private_keys, 3)
    |> Enum.with_index()
    |> Enum.each(fn {testnet_private_key, index} ->
      public_key = Enum.fetch!(rsa_public_keys, index)
      {:RSAPublicKey, modulus_integer, exponent} = public_key
      modulus = :binary.encode_unsigned(modulus_integer)
      EllipticoinStakingContract.set_rsa_public_modulus(modulus, testnet_private_key)
    end)
  end

  @doc """
  Deployment should probably be rewritten in Elixir. Currently there
  aren't any libraries for linking bytecode in Elixir so we deploy with
  truffle instead :/
  """

  def deploy_test_contracts() do
    {result, 0} =
      System.cmd(
        "truffle",
        ["migrate", "--reset"],
        cd: "staking_contract",
        stderr_to_stdout: true
      )

    staking_contract_address =
      Regex.scan(~r/contract address:\s+(0x[\da-fA-F]+)/, result)
      |> Enum.at(-1)
      |> Enum.at(1)

    EllipticoinStakingContract.at(staking_contract_address)

    token_contract_address =
      EllipticoinStakingContract.token()
      |> Utils.ok()
      |> Ethereum.Helpers.bytes_to_hex()

    TestnetToken.at(token_contract_address)
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
      address: Constants.system_address(),
      contract_name: Constants.base_token_name()
    }

    %{
      method: method,
      params: params,
      address: address,
      contract_name: contract_name
    } = Enum.into(options, defaults)

    address = Base.encode16(address, case: :lower)
    path = "/" <> Enum.join([address, contract_name], "/")

    query =
      Plug.Conn.Query.encode(%{
        method: method,
        params: Base.encode16(Cbor.encode(params))
      })

    {:ok, response} = http_get(path, query)
    Cbor.decode!(response.body)
  end

  def post(options \\ []) do
    defaults = %{
      address: Constants.system_address(),
      contract_name: Constants.base_token_name()
    }

    %{
      private_key: private_key,
      nonce: nonce,
      method: method,
      params: params,
      address: address,
      contract_name: contract_name
    } = Enum.into(options, defaults)

    path = "/transactions"
    sender = Ed25519.public_key_from_private_key(private_key)

    transaction =
      Cbor.encode(%{
        sender: sender,
        nonce: nonce,
        method: method,
        params: params,
        address: address,
        contract_name: contract_name
      })

    http_post_signed(path, transaction, private_key)
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
    encoded_block = Block.as_cbor(block)
    message = <<block.number::size(64)>> <> Crypto.hash(encoded_block)
    {:ok, signature} = Ethereum.Helpers.sign(message, private_key)

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
