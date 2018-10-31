defmodule Test.Utils do
  @default_gas_limit 4_712_388
  @default_gas_price 100_000_000_000
  require Integer
  import Binary

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

  def deploy(contract_file_name) do
    contract_binary = File.read!(Path.join(test_support_dir(), contract_file_name))

    private_key = Application.get_env(:blacksmith, :private_key)
    address = private_key_to_address(private_key)

    transaction_count =
      Ethereumex.WebSocketClient.eth_get_transaction_count("0x" <> Base.encode16(address))
      |> elem(1)
      |> parse_hex()
      |> :binary.decode_unsigned()

    transaction_data =
      %Blockchain.Transaction{
        data: contract_binary,
        gas_limit: @default_gas_limit,
        gas_price: @default_gas_price,
        nonce: transaction_count,
        value: 0
      }
      |> Blockchain.Transaction.Signature.sign_transaction(private_key)
      |> Blockchain.Transaction.serialize()
      |> ExRLP.encode()
      |> Base.encode16()

    {:ok, transaction_hash} =
      Ethereumex.WebSocketClient.eth_send_raw_transaction("0x" <> transaction_data)

    Ethereumex.WebSocketClient.eth_subscribe("newHeads")
    {:ok, receipt} = wait_for_receipt(transaction_hash)

    {:ok, receipt["contractAddress"]}
  end

  def wait_for_receipt(transaction_hash) do
    receive do
      _ ->
        nil
    end

    case Ethereumex.WebSocketClient.eth_get_transaction_receipt(transaction_hash) do
      {:ok, nil} -> wait_for_receipt(transaction_hash)
      receipt -> receipt
    end
  end

  def private_key_to_address(private_key) do
    private_key_to_public_key(private_key)
    |> ExthCrypto.Key.der_to_raw()
    |> ExthCrypto.Hash.Keccak.kec()
    |> EVM.Helpers.take_n_last_bytes(20)
  end

  def private_key_to_public_key(private_key) do
    private_key
    |> ExthCrypto.Signature.get_public_key()
    |> elem(1)
  end

  def read_test_wasm(file_name) do
    Path.join([test_support_dir(), "wasm", file_name])
    |> File.read!()
  end

  def test_support_dir() do
    Path.join([File.cwd!(), "test", "support"])
  end
end
