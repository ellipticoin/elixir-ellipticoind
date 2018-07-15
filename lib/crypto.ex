defmodule Crypto do
  @hash_size 256

  def hash_size, do: @hash_size

  def keypair do
    :libsodium_crypto_sign_ed25519.keypair()
  end

  def hash(value) do
    :sha3.hash(@hash_size, value)
  end

  def hash!(value) do
    {:ok, hash}  = hash(value)

    hash
  end
  def sign(message, secret_key) do
    :libsodium_crypto_sign_ed25519.detached(message, secret_key)
  end

  def valid_signature?(signature, message, public_key) do
    case :libsodium_crypto_sign_ed25519.verify_detached(signature, message, public_key) do
      0 -> true
      -1 -> false
    end
  end

  def public_key_from_private_key(private_key) do
    :libsodium_crypto_sign_ed25519.sk_to_pk(private_key)
  end
end
