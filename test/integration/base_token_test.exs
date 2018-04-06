defmodule Integration.BaseTokenTest do
  @host "http://localhost:4047/"
  @sender  Base.decode16!("509c3480af8118842da87369eb616eb7b158724927c212b676c41ce6430d334a", case: :lower)
  @sender_private_key Base.decode16!("01a596e2624497da63a15ef7dbe31f5ca2ebba5bed3d30f3319ef22c481022fd509c3480af8118842da87369eb616eb7b158724927c212b676c41ce6430d334a", case: :lower)
  @receiver  Base.decode16!("027da28b6a46ec1124e7c3c33677b71f4ac4eae2485ff8cb33346aac54c11a30", case: :lower)
  @receiver_private_key Base.decode16!("1e598351b3347ca287da6a77de2ca43fb2f7bd85350d54c870f1333add33443a027da28b6a46ec1124e7c3c33677b71f4ac4eae2485ff8cb33346aac54c11a30", case: :lower)
  @adder_contract_code  File.read!("test/support/adder.wasm")

  use ExUnit.Case

  test "send tokens" do
    post(%{
      private_key: @sender_private_key,
      nonce: 0,
      method: :constructor,
      params: [100],
    })

    {:ok, response} = post(%{
      private_key: @sender_private_key,
      nonce: 1,
      method: :balance_of,
      params: [@sender],
    })

    assert Cbor.decode(response.body) == 100

    post(%{
      private_key: @sender_private_key,
      nonce: 2,
      method: :transfer,
      params: [@receiver, 50],
    })

    {:ok, response} = post(%{
      private_key: @sender_private_key,
      nonce: 3,
      method: :balance_of,
      params: [@sender],
    })

    assert Cbor.decode(response.body) == 50

    post(%{
      private_key: @receiver_private_key,
      nonce: 4,
      method: :transfer,
      params: [@sender, 25],
    })

    {:ok, response} = post(%{
      private_key: @sender_private_key,
      nonce: 5,
      method: :balance_of,
      params: [@sender],
    })

    assert Cbor.decode(response.body) == 75
  end

  test "deploy a contract" do
    nonce = 0
    contract_name = "Adder"
    nonce = Base.encode16(<<nonce::size(32)>>)

    path = Enum.join([nonce, @sender, contract_name], "/")

    put_signed(path, @adder_contract_code, @sender_private_key)

    {:ok, response} = post(%{
      private_key: @sender_private_key,
      contract_name: "Adder",
      address: @sender,
      nonce: 1,
      method: :add,
      params: [1, 2],
    })

    assert Cbor.decode(response.body) == 3
  end


  def get(options \\ []) do
    defaults = %{
      address: Constants.system_address(),
      contract_name: Constants.base_token_name(),
    }
    %{
      method: method,
      params: params,
      address: address,
      contract_name: contract_name,
    } = Enum.into(options, defaults)

    address  = Base.encode16(address, case: :lower)
    path = Enum.join([address, contract_name], "/")
    rpc = Cbor.encode([method, params])

    http_get(path, rpc)
  end

  def post(options \\ []) do
    defaults = %{
      address: Constants.system_address(),
      contract_name: Constants.base_token_name(),
    }
    %{
      private_key: private_key,
      nonce: nonce,
      method: method,
      params: params,
      address: address,
      contract_name: contract_name,
    } = Enum.into(options, defaults)

    nonce = Base.encode16(<<nonce::size(32)>>)
    address  = Base.encode16(address, case: :lower)
    path = Enum.join([nonce, address, contract_name], "/")
    rpc = Cbor.encode([method, params])

    http_post_signed(path, rpc, private_key)
  end

  def http_get(path, message) do
    HTTPoison.get(@host <> path <> "?" <> message)
  end

  def http_post_signed(path, message, private_key) do
    public_key =  Crypto.public_key_from_private_key(private_key)
    signature = Crypto.sign(path <> message, private_key)

    HTTPoison.post(
      @host <> path,
      message,
      headers(public_key, signature)
    )
  end

  def put_signed(path, message, private_key) do
    public_key =  Crypto.public_key_from_private_key(private_key)
    signature = Crypto.sign(message, private_key)

    HTTPoison.put(
      @host <> path,
      message,
      headers(public_key, signature)
    )
  end

  def headers(public_key, signature) do
      %{
        Authorization: "Signature "<> Base.encode16(public_key, case: :lower) <> " " <> Base.encode16(signature, case: :lower)
      }
  end
end
