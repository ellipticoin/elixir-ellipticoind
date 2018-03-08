defmodule Integration.BaseTokenTest do
  @host "http://localhost:4047/"
  @sender  Base.decode16!("b114ed4c88b61b46ff544e9120164cb5dc49a71157c212f76995bf1d6aecab0e", case: :lower)
  @sender_private_key Base.decode16!("2a185960faf3ffa84ff8886e8e2e0f8ba0fff4b91adad23108bfef5204390483b114ed4c88b61b46ff544e9120164cb5dc49a71157c212f76995bf1d6aecab0e", case: :lower)
  @receiver  Base.decode16!("027da28b6a46ec1124e7c3c33677b71f4ac4eae2485ff8cb33346aac54c11a30", case: :lower)
  @receiver_private_key Base.decode16!("1e598351b3347ca287da6a77de2ca43fb2f7bd85350d54c870f1333add33443a027da28b6a46ec1124e7c3c33677b71f4ac4eae2485ff8cb33346aac54c11a30", case: :lower)
  @base_token_contract Base.decode16("93a88d0da2c295543a235e69cf84e9590fa4f7398c8905b2256429fc958f3bdedcb834ae4fdd073f9f3949c78551e8e1c842e408be672e70cd3d74fc6c1601b5", case: :lower)

  use ExUnit.Case

  test "send some tokens" do
    call(%{
      private_key: @sender_private_key,
      nonce: 0,
      method: :constructor,
      params: [100],
    })

    {:ok, response} = call(%{
      private_key: @sender_private_key,
      nonce: 2,
      method: :balance_of,
      params: [@sender, 100],
    })

    assert Cbor.decode(response.body) == 100

    call(%{
      private_key: @sender_private_key,
      nonce: 1,
      method: :transfer,
      params: [@receiver, 50],
    })

    {:ok, response} = call(%{
      private_key: @sender_private_key,
      nonce: 2,
      method: :balance_of,
      params: [@sender],
    })

    assert Cbor.decode(response.body) == 50

    call(%{
      private_key: @receiver_private_key,
      nonce: 0,
      method: :transfer,
      params: [@sender, 25],
    })

    {:ok, response} = call(%{
      private_key: @sender_private_key,
      nonce: 2,
      method: :balance_of,
      params: [@sender],
    })

    assert Cbor.decode(response.body) == 75
  end

  def call(%{
    private_key: private_key,
    nonce: nonce,
    method: method,
    params: params,
  }) do
    rpc = Cbor.encode(%{
      method: method,
      params: params,
    })

    public_key =  Crypto.public_key_from_private_key(private_key)
    message = public_key <> <<nonce::size(32)>> <> rpc
    signature = Crypto.sign(message, private_key)
    IO.inspect Crypto.valid_signature?(signature, message, public_key)

    HTTPoison.post(
      @host,
      signature <> message
    )
  end
end
