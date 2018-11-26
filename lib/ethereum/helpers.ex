defmodule Ethereum.Helpers do
  @address_size 20

  def deploy(module_name, args \\ []) do
    contract_name =
      to_string(module_name)
      |> String.split(".")
      |> List.last()

    bin_file_name = Path.join(["priv", "ethereum_contracts", "#{contract_name}.hex"])
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
    message_hash = Crypto.hash("\x19Ethereum Signed Message:\n#{message_size}" <> message)

    case :libsecp256k1.ecdsa_recover_compact(message_hash, signature, :uncompressed, recovery_id) do
      {:ok, public_key} ->
        address_from_public_key(public_key) == address

      {:error, _reason} ->
        false
    end
  end

  def address_from_private_key(private_key) do
    private_key
    |> get_secp256k1_public_key()
    |> elem(1)
    |> address_from_public_key()
  end

  defp address_from_public_key(<<4>> <> public_key) do
    public_key
    |> Crypto.hash()
    |> take_n_last_bytes(@address_size)
  end

  defp get_secp256k1_public_key(private_key) do
    case :libsecp256k1.ec_pubkey_create(private_key, :uncompressed) do
      {:ok, public_key} -> {:ok, public_key}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  def subscribe_to_new_blocks() do
    # Ethereumex.WebSocketClient.eth_subscribe("newHeads")
  end

  def mine_block() do
    # Ethereumex.WebSocketClient.request("evm_mine", [], [])
  end

  def my_ethereum_address() do
    Application.fetch_env!(:blacksmith, :ethereum_private_key)
      |> private_key_to_address
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

  def sign(message, private_key) do
    message_size = byte_size(message)
    message_hash = Crypto.hash("\x19Ethereum Signed Message:\n#{message_size}" <> message)
    {:ok, signature, recovery_id} =
      :libsecp256k1.ecdsa_sign_compact(message_hash, private_key, :default, <<>>)

    {:ok, _public_key} = :libsecp256k1.ecdsa_recover_compact(message_hash, signature, :uncompressed, recovery_id)
    {:ok, signature <> <<recovery_id>>}
  end

  def take_n_last_bytes(data, n) do
    length = byte_size(data)

    :binary.part(data, length - n, n)
  end

  def hex_to_bytes("0x" <> hex), do: Base.decode16!(hex, case: :lower)
  def hex_to_int(hex), do: hex_to_bytes(hex) |> :binary.decode_unsigned()
  def bytes_to_hex(bytes), do: "0x" <> Base.encode16(bytes, case: :lower)
  def abi_file_name(contract_name), do: Path.join(["priv", "ethereum_contracts", "#{contract_name}.abi"])
  defp bin_file_name(contract_name), do: Path.join(["priv", "ethereum_contracts", "#{contract_name}.bin"])
end
