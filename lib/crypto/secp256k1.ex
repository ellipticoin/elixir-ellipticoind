defmodule Crypto.Secp256k1 do
  def sign(message, secret_key) do
    {:ok, signature, recovery_id} =
      :libsecp256k1.ecdsa_sign_compact(message, secret_key, :default, <<>>)

    signature <> <<recovery_id>>
  end
end
