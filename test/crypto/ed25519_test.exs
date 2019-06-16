defmodule Crypto.Ed25519Test do
  use ExUnit.Case
  alias Crypto.Ed25519

  test "Crypto.Ed25519" do
    message = "test"
    {public_key, private_key} = Ed25519.keypair()
    assert Ed25519.private_key_to_public_key(private_key) == public_key

    signature = Ed25519.sign(message, private_key)
    assert Ed25519.valid_signature?(signature, message, public_key)
  end
end
