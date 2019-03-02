defmodule Crypto.Ed25519 do
  def keypair do
    :libsodium_crypto_sign_ed25519.keypair()
  end

  def valid_signature?(signature, message, public_key) do
    case :libsodium_crypto_sign_ed25519.verify_detached(signature, message, public_key) do
      0 -> true
      -1 -> false
    end
  end

  def private_key_to_public_key(private_key) do
    :libsodium_crypto_sign_ed25519.sk_to_pk(private_key)
  end

  def sign(message, secret_key) do
    :libsodium_crypto_sign_ed25519.detached(message, secret_key)
  end
end
