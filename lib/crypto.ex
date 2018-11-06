defmodule Crypto do
  @hash_size 256
  @ethereum_address_size 20

  def hash_size, do: @hash_size

  def keypair do
    :libsodium_crypto_sign_ed25519.keypair()
  end

  def hash(value) do
    :keccakf1600.sha3_256(value)
  end

  def sign(message, secret_key), do: sign_ed25519(message, secret_key)

  def sign_ed25519(message, secret_key) do
    :libsodium_crypto_sign_ed25519.detached(message, secret_key)
  end

  def sign_secp256k1(message, secret_key) do
    {:ok, signature, recovery_id} =
      :libsecp256k1.ecdsa_sign_compact(message, secret_key, :default, <<>>)

    signature <> <<recovery_id>>
  end

  def valid_signature_ed25519?(signature, message, public_key) do
    case :libsodium_crypto_sign_ed25519.verify_detached(signature, message, public_key) do
      0 -> true
      -1 -> false
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
    |> hash()
    |> take_n_last_bytes(@ethereum_address_size)
  end

  defp get_secp256k1_public_key(private_key) do
    case :libsecp256k1.ec_pubkey_create(private_key, :uncompressed) do
      {:ok, public_key} -> {:ok, public_key}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  def valid_ethereum_signature?(
        <<signature::binary-size(64), recovery_id::8-integer>>,
        message,
        address
      ) do
    case :libsecp256k1.ecdsa_recover_compact(message, signature, :uncompressed, recovery_id) do
      {:ok, public_key} ->
        address_from_public_key(public_key) == address

      {:error, _reason} ->
        false
    end
  end

  def take_n_last_bytes(data, n) do
    length = byte_size(data)

    :binary.part(data, length - n, n)
  end

  def public_key_from_private_key_ed25519(private_key) do
    :libsodium_crypto_sign_ed25519.sk_to_pk(private_key)
  end
end
