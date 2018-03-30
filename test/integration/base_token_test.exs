defmodule Integration.BaseTokenTest do
  @host "http://localhost:4047/"
  @system_address  Base.decode16!("0000000000000000000000000000000000000000000000000000000000000000", case: :lower)
  @sender  Base.decode16!("509c3480af8118842da87369eb616eb7b158724927c212b676c41ce6430d334a", case: :lower)
  @sender_private_key Base.decode16!("01a596e2624497da63a15ef7dbe31f5ca2ebba5bed3d30f3319ef22c481022fd509c3480af8118842da87369eb616eb7b158724927c212b676c41ce6430d334a", case: :lower)
  @receiver  Base.decode16!("027da28b6a46ec1124e7c3c33677b71f4ac4eae2485ff8cb33346aac54c11a30", case: :lower)
  @receiver_private_key Base.decode16!("1e598351b3347ca287da6a77de2ca43fb2f7bd85350d54c870f1333add33443a027da28b6a46ec1124e7c3c33677b71f4ac4eae2485ff8cb33346aac54c11a30", case: :lower)
  @base_token_contract Base.decode16!("02082cf471002b5c5dfefdd6cbd30666ff02c4df90169f766877caec26ed4f88", case: :lower)
  @adder_contract_code  File.read!("test/support/adder.wasm")

  use ExUnit.Case

  test "send tokens" do
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
      params: [@sender],
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

  test "deploy a contract" do
    public_key =  Crypto.public_key_from_private_key(@sender_private_key)
    message = public_key <>
      <<0::size(32)>> <>
      Helpers.pad_bytes_right("Echo")

    signature = Crypto.sign(message, @sender_private_key)

    HTTPoison.put(
      @host,
      signature <> message <> @adder_contract_code
    )
  end


  def call(options \\ []) do
    defaults = %{
      address: Constants.system_address(),
      contract_name: Helpers.pad_bytes_right(Constants.base_token_name()),
    }
    %{
      private_key: private_key,
      nonce: nonce,
      method: method,
      params: params,
      address: address,
      contract_name: contract_name,
    } = Enum.into(options, defaults)


    rpc = Cbor.encode([
      method,
      params,
    ])
    public_key =  Crypto.public_key_from_private_key(private_key)
    message = public_key <>
      <<nonce::size(32)>> <>
      Constants.system_address() <>
      Helpers.pad_bytes_right(Constants.base_token_name()) <>
      rpc

    signature = Crypto.sign(message, private_key)

    HTTPoison.post(
      @host,
      signature <> message
    )
  end
end
