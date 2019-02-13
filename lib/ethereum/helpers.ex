defmodule Ethereum.Helpers do
  require Integer
  @address_size 20

  def deploy(module_name, args \\ []) do
    contract_name =
      to_string(module_name)
      |> String.split(".")
      |> List.last()

    abi = ExW3.load_abi(abi_file_name(contract_name))
    bin = ExW3.load_bin(bin_file_name(contract_name))
    ExW3.Contract.register(module_name, abi: abi)

    {:ok, address, _tx_hash} =
      ExW3.Contract.deploy(module_name,
        bin: bin,
        args: args,
        options: %{
          gas: 6_721_975,
          from: ExW3.accounts() |> Enum.at(0)
        }
      )

    ExW3.Contract.at(module_name, address)
    {:ok, address}
  end

  def valid_signature?(
        <<signature::binary-size(64), recovery_id::8-integer>>,
        message,
        address
      ) do
    message_size = byte_size(message)
    message_hash = Crypto.keccak256("\x19Ethereum Signed Message:\n#{message_size}" <> message)

    case :libsecp256k1.ecdsa_recover_compact(message_hash, signature, :uncompressed, recovery_id) do
      {:ok, public_key} ->
        public_key_to_address(public_key) == address

      {:error, _reason} ->
        false
    end
  end

  def subscribe_to_new_blocks() do
    Ethereumex.WebSocketClient.eth_subscribe("newHeads")
  end

  def mine_block() do
    Ethereumex.WebSocketClient.request("evm_mine", [], [])
    :timer.sleep(1000)
  end

  def my_ethereum_address() do
    Application.fetch_env!(:blacksmith, :ethereum_private_key)
    |> private_key_to_address
  end

  def private_key_to_address(private_key) do
    private_key_to_public_key(private_key)
    |> public_key_to_address()
  end

  def public_key_to_address(public_key) do
    public_key
    |> der_to_raw()
    |> Crypto.keccak256()
    |> take_n_last_bytes(@address_size)
  end

  def private_key_to_public_key(private_key) do
    private_key
    |> ExthCrypto.Signature.get_public_key()
    |> elem(1)
  end

  def sign(message, private_key) do
    message_size = byte_size(message)
    message_hash = Crypto.keccak256("\x19Ethereum Signed Message:\n#{message_size}" <> message)

    {:ok, signature, recovery_id} =
      :libsecp256k1.ecdsa_sign_compact(message_hash, private_key, :default, <<>>)

    {:ok, signature <> <<recovery_id>>}
  end

  def take_n_last_bytes(data, n) do
    length = byte_size(data)

    :binary.part(data, length - n, n)
  end

  def hex_to_bytes("0x" <> hex), do: hex_to_bytes(hex)

  def hex_to_bytes(hex) when Integer.is_odd(byte_size(hex)),
    do: hex_to_bytes("0" <> hex)

  def hex_to_bytes(hex), do: Base.decode16!(hex, case: :mixed)
  def hex_to_int(hex), do: hex_to_bytes(hex) |> :binary.decode_unsigned()
  def bytes_to_hex(bytes), do: "0x" <> Base.encode16(bytes, case: :lower)

  def abi_file_name(contract_name),
    do: Application.app_dir(:blacksmith, ["priv", "ethereum_contracts", "#{contract_name}.abi"])

  defp der_to_raw(<<0x04, public_key::binary()>>), do: public_key
  defp der_to_raw(public_key), do: public_key

  defp bin_file_name(contract_name),
    do: Application.app_dir(:blacksmith, ["priv", "ethereum_contracts", "#{contract_name}.hex"])
end
