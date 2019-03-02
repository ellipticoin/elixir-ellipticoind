defmodule Crypto do
  alias Crypto.Ed25519
  alias Crypto.SHA256
  @hash_size 256

  defdelegate keypair, to: Ed25519
  defdelegate private_key_to_public_key(private_key), to: Ed25519

  def hash(message) when is_map(message),
    do: hash(Cbor.encode(message))
  defdelegate hash(message), to: SHA256

  def hash_size, do: @hash_size

  def sign(message, private_key) when is_map(message),
    do: sign(Cbor.encode(message), private_key)

  defdelegate sign(message, private_key), to: Ed25519
end
