defmodule Integration.BaseTokenTest do
  @host "http://localhost:4047/"
  @sender <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
  @receiver <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2>>
  use ExUnit.Case

  test "send some tokens" do
    HTTPoison.post(
      @host,
      Cbor.encode(%{
        method: :constructor,
        params: [99]
      })
    )


    {:ok, response} = HTTPoison.post(
      @host,
      Cbor.encode(%{
        method: :transfer,
        params: [@receiver, 1]
      })
    )

    {:ok, response} = HTTPoison.post(
      @host,
      Cbor.encode(%{
        method: :balance_of,
        params: [@sender]
      })
    )

    assert Cbor.decode(response.body) == 98
  end
end
