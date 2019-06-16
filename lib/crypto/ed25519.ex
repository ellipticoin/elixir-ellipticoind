defmodule Crypto.Ed25519 do
  use Rustler, otp_app: :ellipticoind, crate: :ed25519

  def keypair(), do: error()
  def valid_signature(_signature, _message, _public_key), do: error()
  def valid_signature?(signature, message, public_key), do:
    valid_signature(signature, message, public_key)
  def private_key_to_public_key(_private_key), do: error()
  def sign(_message, _secret_key), do: error()
  defp error, do: :erlang.nif_error(:nif_not_loaded)
end
