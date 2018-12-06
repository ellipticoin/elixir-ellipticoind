defmodule Ethereum.Contracts.EllipticoinStakingContract do
  import Ethereum.Helpers
  use GenServer

  def init(args) do
    {:ok, args}
  end

  def start_link(opts) do
    ExW3.Contract.start_link()
    contract_address = Application.fetch_env!(:blacksmith, :staking_contract_address)
    abi = ExW3.load_abi(abi_file_name("EllipticoinStakingContract"))
    ExW3.Contract.register(__MODULE__, abi: abi)
    ExW3.Contract.at(__MODULE__, bytes_to_hex(contract_address))
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def deposit(amount, address),
    do:
      ExW3.Contract.send(__MODULE__, :deposit, [amount], %{
        from: address,
        gas: 6_721_975
      })

  def submit_block(block_hash, <<r::bytes-size(32), s::bytes-size(32), recovery_id::8-integer>>) do
abi_encoded_data = ABI.encode("submitBlock(bytes32,uint8,bytes32,bytes32)", [block_hash, recovery_id + 27, r, s])
    contract_address = Application.fetch_env!(:blacksmith, :staking_contract_address)
    ethereum_private_key = Application.fetch_env!(:blacksmith, :ethereum_private_key)

IO.inspect recovery_id + 27, label: "v"
IO.inspect r |> Base.encode16(case: :lower), label: "r"
IO.inspect s |> Base.encode16(case: :lower), label: "s"
    {:ok, transaction_count} = Ethereumex.WebSocketClient.eth_get_transaction_count(Ethereum.Helpers.bytes_to_hex(Ethereum.Helpers.my_ethereum_address()))
    # IO.inspect Ethereum.Helpers.bytes_to_hex(Ethereum.Helpers.my_ethereum_address())
    IO.inspect Ethereumex.WebSocketClient.eth_get_balance(Ethereum.Helpers.bytes_to_hex(Ethereum.Helpers.my_ethereum_address()))
    transaction_data = %Blockchain.Transaction{
      data: abi_encoded_data,
      gas_price: 1000000003,
      gas_limit: 4712388,
      nonce: Ethereum.Helpers.hex_to_int(transaction_count),
      to: contract_address,
      value: 0
    }
    |> Blockchain.Transaction.Signature.sign_transaction(ethereum_private_key)
    |> Blockchain.Transaction.serialize()
    |> ExRLP.encode()
    |> Base.encode16(case: :lower)

    IO.inspect Ethereumex.WebSocketClient.eth_send_raw_transaction("0x" <> transaction_data)
  end
  def last_signature() do
    {:ok, v, r, s} = ExW3.Contract.call(__MODULE__, :lastSignature)

    {:ok, r <> s <> :binary.encode_unsigned(v)}
  end

  def winner(),
    do: ExW3.Contract.call(__MODULE__, :winner)

  def block_hash(),
    do: ExW3.Contract.call(__MODULE__, :blockHash)

  def totalStake(),
    do: ExW3.Contract.call(__MODULE__, :totalStake)
end
