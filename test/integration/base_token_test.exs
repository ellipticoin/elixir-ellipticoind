defmodule Integration.BaseTokenTest do
  @host "http://localhost:4047/"
  @sender  Base.decode16!("b114ed4c88b61b46ff544e9120164cb5dc49a71157c212f76995bf1d6aecab0e", case: :lower)
  @private_key Base.decode16!("2a185960faf3ffa84ff8886e8e2e0f8ba0fff4b91adad23108bfef5204390483b114ed4c88b61b46ff544e9120164cb5dc49a71157c212f76995bf1d6aecab0e", case: :lower)
  @receiver <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2>>
  @base_token_contract Base.decode16("b114ed4c88b61b46ff544e9120164cb5dc49a71157c212f76995bf1d6aecab0e", case: :lower)
  @private_key
  use ExUnit.Case

  test "send some tokens" do
    call(0, :constructor, [100])
    call(1, :transfer, [@receiver, 3])
    {:ok, response} = call(1, :balance_of, [@sender])

    assert Cbor.decode(response.body) == 97
  end

  def call(nonce, method, params) do
    rpc = Cbor.encode(%{
      method: method,
      params: params,
    })

    message = @sender <> <<nonce::size(32)>> <> rpc
    signature = Crypto.sign(message, @private_key)

    HTTPoison.post(
      @host,
      signature <> message
    )
  end
end
