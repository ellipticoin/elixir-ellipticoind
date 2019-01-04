defmodule Crypto do
  alias Crypto.Ed25519
  @hash_size 256

  def hash_size, do: @hash_size
  def keccak256(message), do: :keccakf1600.sha3_256(message)
  def sha256(message), do: :crypto.hash(:sha256, message)
  def sign(message, secret_key), do: Ed25519.sign(message, secret_key)
  def hash(message), do: sha256(message)
end
