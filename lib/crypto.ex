defmodule Crypto do
  @hash_size 256

  def hash_size, do: @hash_size

  def keypair do
    :libsodium_crypto_sign_ed25519.keypair()
  end

  def hash(message) do
    sha256(message)
  end

  def keccak256(message), do: :keccakf1600.sha3_256(message)
  def sha256(message), do: :crypto.hash(:sha256, message)

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

  def public_key_from_private_key_ed25519(private_key) do
    :libsodium_crypto_sign_ed25519.sk_to_pk(private_key)
  end
end
