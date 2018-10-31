defmodule Integration.BaseTokenTest do
  @host "http://localhost:4047"

  import Test.Utils
  use NamedAccounts
  use ExUnit.Case

  setup do
    Redis.reset()

    on_exit(fn ->
      Redis.reset()
    end)

    :ok
  end

  test "send tokens asynchronously" do
    set_balances(%{
      @alice => 100,
      @bob => 100
    })

    post(%{
      private_key: @alices_private_key,
      nonce: 2,
      method: :transfer,
      params: [@bob, 50]
    })

    TransactionProccessor.proccess_transactions(1)
    TransactionProccessor.wait_until_done()

    {:ok, response} =
      get(%{
        private_key: @alices_private_key,
        method: :balance_of,
        params: [@alice]
      })

    assert Cbor.decode!(response.body) == 50
  end

  # test "deploy a contract" do
  #   nonce = 0
  #   contract_name = "Adder"
  #   path = "/contracts"
  #   sender =  Crypto.public_key_from_private_key(@alices_private_key)
  #   deployment = Cbor.encode(%{
  #     contract_name: contract_name,
  #     sender: sender,
  #     code: @adder_contract_code,
  #     params: [],
  #     nonce: nonce,
  #   })
  #
  #   put_signed(path, deployment, @alices_private_key)
  #
  #   {:ok, response} = get(%{
  #     private_key: @alices_private_key,
  #     contract_name: "Adder",
  #     address: @alice,
  #     nonce: 1,
  #     method: :add,
  #     params: [1, 2],
  #   })
  #
  #   assert Cbor.decode!(response.body) == 3
  # end

  # test "updates the blockhash" do
  #   post(%{
  #     private_key: @alices_private_key,
  #     nonce: 0,
  #     method: :constructor,
  #     params: [100],
  #   })
  #
  #   {:ok, response} = get(%{
  #     contract_name: Constants.base_api_name(),
  #     method: :block_hash,
  #     params: [],
  #   })
  #
  #   assert Cbor.decode!(response.body) == Base.decode16!("D2F64658686ADEE3EBE827A27AE1F691D21A24BA37975B3F18856307D0A0283D")
  #
  #   post(%{
  #     private_key: @alices_private_key,
  #     nonce: 2,
  #     method: :transfer,
  #     params: [@bob, 50],
  #   })
  #
  #   {:ok, response} = get(%{
  #     contract_name: Constants.base_api_name(),
  #     method: :block_hash,
  #     params: [],
  #   })
  #
  #   assert Cbor.decode!(response.body) == Base.decode16!("B13812DDF53A2A1770D91803F6FF75350D18C0CAA8FD7B9F31B961C29D91516B")
  # end

  def get(options \\ []) do
    defaults = %{
      address: Constants.system_address(),
      contract_name: Constants.base_token_name()
    }

    %{
      method: method,
      params: params,
      address: address,
      contract_name: contract_name
    } = Enum.into(options, defaults)

    address = Base.encode16(address, case: :lower)
    path = "/" <> Enum.join([address, contract_name], "/")

    query =
      Plug.Conn.Query.encode(%{
        method: method,
        params: Base.encode16(Cbor.encode(params))
      })

    http_get(path, query)
  end

  def post(options \\ []) do
    defaults = %{
      address: Constants.system_address(),
      contract_name: Constants.base_token_name()
    }

    %{
      private_key: private_key,
      nonce: nonce,
      method: method,
      params: params,
      address: address,
      contract_name: contract_name
    } = Enum.into(options, defaults)

    path = "/transactions"
    sender = Crypto.public_key_from_private_key(private_key)

    transaction =
      Cbor.encode(%{
        sender: sender,
        nonce: nonce,
        method: method,
        params: params,
        address: address,
        contract_name: contract_name
      })

    http_post_signed(path, transaction, private_key)
  end

  def http_get(path, query) do
    HTTPoison.get(@host <> path <> "?" <> query)
  end

  def http_post_signed(path, message, private_key) do
    signature = Crypto.sign(message, private_key)

    HTTPoison.post(
      @host <> path,
      message,
      headers(signature),
      timeout: 50_000,
      recv_timeout: 50_000
    )
  end

  def put_signed(path, message, private_key) do
    signature =
      Crypto.sign(
        message,
        private_key
      )

    HTTPoison.put(
      @host <> path,
      message,
      headers(signature)
    )
  end

  def headers(signature) do
    %{
      "Content-Type": "application/cbor",
      Authorization: "Signature " <> Base.encode16(signature, case: :lower)
    }
  end
end
