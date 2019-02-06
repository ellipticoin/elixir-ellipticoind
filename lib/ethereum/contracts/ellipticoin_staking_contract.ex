defmodule Ethereum.Contracts.EllipticoinStakingContract do
  import Utils
  import Ethereum.Helpers
  alias Blacksmith.Models.Block
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(args) do
    abi = ExW3.load_abi(abi_file_name("EllipticoinStakingContract"))
    ExW3.Contract.register(__MODULE__, abi: abi)
    address = Application.fetch_env!(:blacksmith, :staking_contract_address)
    ExW3.Contract.at(__MODULE__, address)

    {:ok, args}
  end

  def address() do
    ExW3.Contract.address(__MODULE__)
  end

  def at(address) do
    ExW3.Contract.at(__MODULE__, address)
  end

  def register() do
    abi = ExW3.load_abi(abi_file_name("EllipticoinStakingContract"))
    ExW3.Contract.register(__MODULE__, abi: abi)
  end

  def deposit(amount, from),
    do:
      ExW3.Contract.send(__MODULE__, :deposit, [amount], %{
        from: from,
        gas: 6_721_975
      })

  def set_rsa_public_modulus(public_modulus, private_key) do
    {:ok, transaction_count} =
      private_key
      |> Ethereum.Helpers.private_key_to_address()
      |> Ethereum.Helpers.bytes_to_hex()
      |> Ethereumex.WebSocketClient.eth_get_transaction_count()

    abi_encoded_data = ABI.encode("setRSAPublicModulus(bytes)", [public_modulus])

    transaction_data =
      %Blockchain.Transaction{
        data: abi_encoded_data,
        gas_price: 1_000_000_000,
        gas_limit: 3_000_000,
        nonce: Ethereum.Helpers.hex_to_int(transaction_count),
        to: Ethereum.Helpers.hex_to_bytes(address()),
        value: 0
      }
      |> Blockchain.Transaction.Signature.sign_transaction(private_key)
      |> Blockchain.Transaction.serialize()
      |> ExRLP.encode()
      |> Base.encode16(case: :lower)

    Ethereumex.WebSocketClient.eth_send_raw_transaction("0x" <> transaction_data)
  end

  def submit_block(block_number, block_hash, signature) do
    abi_encoded_data =
      ABI.encode("submitBlock(uint256,bytes32,bytes)", [block_number, block_hash, signature])

    ethereum_private_key = Application.fetch_env!(:blacksmith, :ethereum_private_key)

    {:ok, transaction_count} =
      Ethereumex.WebSocketClient.eth_get_transaction_count(
        Ethereum.Helpers.bytes_to_hex(Ethereum.Helpers.my_ethereum_address())
      )

    transaction_data =
      %Blockchain.Transaction{
        data: abi_encoded_data,
        gas_price: 1_000_000_003,
        gas_limit: 4_712_388,
        nonce: Ethereum.Helpers.hex_to_int(transaction_count),
        to: Ethereum.Helpers.hex_to_bytes(address()),
        value: 0
      }
      |> Blockchain.Transaction.Signature.sign_transaction(ethereum_private_key)
      |> Blockchain.Transaction.serialize()
      |> ExRLP.encode()
      |> Base.encode16(case: :lower)

    Ethereumex.WebSocketClient.eth_send_raw_transaction("0x" <> transaction_data)
  end

  def set_block(block_hash) do
    private_key = Application.fetch_env!(:blacksmith, :ethereum_private_key)

    {:ok, transaction_count} =
      private_key
      |> Ethereum.Helpers.private_key_to_address()
      |> Ethereum.Helpers.bytes_to_hex()
      |> Ethereumex.WebSocketClient.eth_get_transaction_count()

    abi_encoded_data = ABI.encode("setBlock(bytes32)", [block_hash])

    transaction_data =
      %Blockchain.Transaction{
        data: abi_encoded_data,
        gas_price: 1_000_000_000,
        gas_limit: 3_000_000,
        nonce: Ethereum.Helpers.hex_to_int(transaction_count),
        to: Ethereum.Helpers.hex_to_bytes(address()),
        value: 0
      }
      |> Blockchain.Transaction.Signature.sign_transaction(private_key)
      |> Blockchain.Transaction.serialize()
      |> ExRLP.encode()
      |> Base.encode16(case: :lower)

    Ethereumex.WebSocketClient.eth_send_raw_transaction("0x" <> transaction_data)
  end

  def last_signature(),
    do:
      ExW3.Contract.call(__MODULE__, :lastSignature)
      |> ok()

  def get_current_block() do
    %Block{
      winner: winner() |> ok,
      number: block_number() |> ok,
      block_hash: block_hash() |> ok
    }
  end

  def get_rsa_public_modulus(address),
    do: ExW3.Contract.call(__MODULE__, :getRSAPublicModulus, [ExW3.to_decimal(address)])

  def verify_rsa_signature(message, signature, address),
    do:
      ExW3.Contract.call(__MODULE__, :verifyRSASignature, [
        message,
        signature,
        ExW3.to_decimal(address)
      ])

  def winner(),
    do: ok(ExW3.Contract.call(__MODULE__, :winner))

  def balance_of(address),
    do: ExW3.Contract.call(__MODULE__, :balanceOf, [ExW3.to_decimal(address)])

  def token(),
    do: ExW3.Contract.call(__MODULE__, :token)

  def block_hash(),
    do: ExW3.Contract.call(__MODULE__, :blockHash)

  def block_number(),
    do: ok(ExW3.Contract.call(__MODULE__, :blockNumber))

  def total_stake(),
    do: ExW3.Contract.call(__MODULE__, :totalStake)
end
