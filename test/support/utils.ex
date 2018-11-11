defmodule Test.Utils do
  @host "http://localhost:4047"
  @default_gas_limit 6_721_975
  @default_gas_price 20_000_000_000
  require Integer
  import Binary
  alias Ethereum.Contracts.{EllipticoinStakingContract, TestnetToken}

  def set_balances(balances) do
    token_balance_address =
      Constants.system_address() <> (Constants.base_token_name() |> pad_trailing(32))

    for {address, balance} <- balances do
      Redis.set_binary(token_balance_address <> address, <<balance::little-size(64)>>)
    end
  end

  def parse_hex("0x" <> hex_data), do: parse_hex(hex_data)

  def parse_hex(hex_data) when Integer.is_odd(byte_size(hex_data)),
    do: parse_hex("0" <> hex_data)

  def parse_hex(hex_data), do: Base.decode16!(hex_data, case: :mixed)

  def checkout_repo() do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Blacksmith.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Blacksmith.Repo, {:shared, self()})
  end

  def mine_block_on_parent_chain() do
    Ethereumex.WebSocketClient.request("evm_mine", [], [])
  end

  def deploy_and_fund_staking_contract() do
    starting_stake = 100
    random_seed = <<0::256>>
    ExW3.Contract.start_link()
    address = Enum.at(ExW3.accounts(), 0)

    {:ok, token_contract_address} =
      Ethereum.Helpers.deploy(TestnetToken, ["[testnet] DAI Token", "DAI", 3])

    {:ok, staking_contract_address} =
      Ethereum.Helpers.deploy(EllipticoinStakingContract, [
        ExW3.to_decimal(token_contract_address),
        random_seed
      ])

    Enum.each(Enum.take(ExW3.accounts(), 3), fn account ->
      TestnetToken.mint(account, starting_stake)
      TestnetToken.approve(staking_contract_address, starting_stake, account)
      EllipticoinStakingContract.deposit(starting_stake, account)
    end)

    {:ok, staking_contract_address}
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
    sender = Crypto.public_key_from_private_key_ed25519(private_key)

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
      @host <> "/nodes",
      Cbor.encode(%{
        url: "http://localhost:#{port}/",
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
        "Content-Type": "application/cbor",
      }
    end
  end
end
