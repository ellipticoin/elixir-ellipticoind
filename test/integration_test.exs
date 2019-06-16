defmodule Integration.MiningTest do
  import Test.Utils
  use NamedAccounts
  use ExUnit.Case
  alias Ellipticoind.Storage
  alias Ellipticoind.Models.{Block, Transaction}
  alias Ellipticoind.Miner
  use OK.Pipe

  setup do
    Redis.reset()
    checkout_repo()
    SystemContracts.deploy()

    on_exit(fn ->
      Redis.reset()
      File.rm_rf!(Config.rocksdb_path())
    end)

    :ok
  end

  test "mining a block" do
    set_balances(%{
      @alice => 100,
      @bob => 100
    })

    post(
      %{
        nonce: 1,
        function: :transfer,
        arguments: [@bob, 50]
      },
      @alices_private_key
    )

    Miner.start_link()

    P2P.Transport.Test.subscribe_to_test_broadcasts(self())

    broadcasted_block =
      receive do
        {:p2p, nil, block} -> block |> Cbor.decode!()
      end

    new_block = poll_for_block(0)
    assert Block.Validations.valid_proof_of_work_value?(broadcasted_block)
    assert new_block.number == 0

    assert new_block.transactions
           |> Enum.map(fn transaction ->
             Map.take(
               transaction,
               [
                 :arguments,
                 :contract_address,
                 :contract_name,
                 :function,
                 :return_code,
                 :return_value,
                 :sender
               ]
             )
           end) ==
             [
               %{
                 arguments: [],
                 contract_address: <<0::256>>,
                 contract_name: :BaseToken,
                 function: :mint,
                 return_code: 0,
                 return_value: nil,
                 sender: Config.public_key()
               },
               %{
                 arguments: [@bob, 50],
                 contract_address: <<0::256>>,
                 contract_name: :BaseToken,
                 function: :transfer,
                 return_code: 0,
                 return_value: nil,
                 sender: @alice
               }
             ]

    assert is_integer(new_block.proof_of_work_value)
    assert byte_size(new_block.hash) == 32
    assert byte_size(new_block.changeset_hash) == 32
    refute new_block.hash == <<0::256>>
    refute Map.has_key?(new_block, :parent_hash)

    assert get_balance(@alice) == 50
    assert get_balance(Config.public_key()) == 640_000
  end

  test "a new block is mined on the parent chain and another ellipticoind is the winner" do
    set_balances(%{
      @alice => 100,
      @bob => 100
    })

    transaction =
      %Transaction{
        block_hash: nil,
        nonce: 1,
        contract_name: :BaseToken,
        contract_address: <<0::256>>,
        function: :transfer,
        return_code: 0,
        return_value: nil,
        arguments: [@bob, 50],
        execution_order: 0
      }
      |> Transaction.sign(@alices_private_key)

    block_bytes =
      %Block{
        number: 0,
        proof_of_work_value: 777,
        hash: <<0::256>>,
        changeset_hash:
          Base.decode16!("6CAD99E2AC8E9D4BACC64E8FC9DE852D7C5EA3E602882281CFDFE1C562967A79"),
        transactions: [transaction],
        winner: @bob
      }
      |> Block.as_binary()

    P2P.Transport.Test.receive(block_bytes)

    poll_for_block(0)
    assert get_balance(@alice) == 50
    assert get_balance(@bob) == 150
  end

  test "creating a contract" do
    post(
      %{
        contract_name: :system,
        nonce: 0,
        function: :create_contract,
        arguments: [:state, test_contract_code(:state)]
      },
      @alices_private_key
    )

    post(
      %{
        contract_address: @alice,
        contract_name: :state,
        nonce: 1,
        function: :set_memory,
        arguments: [:value]
      },
      @alices_private_key
    )

    Miner.start_link()

    poll_for_block(0)
    :timer.sleep(100)

    key = Storage.to_key(@alice, :state, "value")
    {:ok, %{body: body}} = http_get("/memory/#{Base.url_encode64(key)}")
    assert Cbor.decode!(body) == :value
  end
end
