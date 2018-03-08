defmodule Crypto do
  def keypair do
    %{public: public, secret: secret} = :enacl.crypto_sign_ed25519_keypair

    {
      public,
      secret,
    }
  end

  def sign(data, secret_key) do
    :enacl.sign_detached(data, secret_key)
  end

  def valid_signature?(signature, data, public_key) do
    case :enacl.sign_verify_detached(signature, data, public_key) do
      {:ok, _data} -> true
      {:error, _message} -> false
    end
  end
end
