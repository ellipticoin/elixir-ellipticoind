defmodule Crypto.RSA do
  def parse_pem(pem) do
    [key] = :public_key.pem_decode(pem)
    :public_key.pem_entry_decode(key)
  end

  def sign(data, private_key) do
    :public_key.sign(data, :sha256, private_key)
  end

  def verify(message, signature, public_key) do
    :public_key.verify(message, :sha256, signature, public_key)
  end

  def private_key_to_public_key(private_key) do
    case private_key do
      {:RSAPrivateKey, :"two-prime", modulus, exponent, _, _, _, _, _, _, _} ->
        {:RSAPublicKey, modulus, exponent}

      _ ->
        :invalid_private_key
    end
  end
end
