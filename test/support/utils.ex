defmodule Test.Utils do
  @default_gas_limit 6_721_975
  @default_gas_price 20_000_000_000
  require Integer
  import Binary
  alias EthereumContracts.{EllipticoinStakingContract, TestnetToken}

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
  end

  def deploy_and_fund_staking_contract() do
    amount = 100
    random_seed = <<0::256>>
    ExW3.Contract.start_link()
    address = Enum.at(ExW3.accounts(), 0)
    {:ok, token_contract_address} = EthereumContracts.deploy(TestnetToken, ["[testnet] DAI Token", "DAI", 3])

    {:ok, staking_contract_address} =
      EthereumContracts.deploy(EllipticoinStakingContract, [ExW3.to_decimal(token_contract_address), random_seed])

    Enum.each(Enum.take(ExW3.accounts(), 3), fn account ->
      TestnetToken.mint(account, amount)
      TestnetToken.approve(staking_contract_address, amount, account)
      EllipticoinStakingContract.deposit(amount, address)
    end)

    {:ok, winner} = EllipticoinStakingContract.winner()
  end

  def read_test_wasm(file_name) do
    Path.join([test_support_dir(), "wasm", file_name])
    |> File.read!()
  end

  def test_support_dir() do
    Path.join([File.cwd!(), "test", "support"])
  end
end
