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
    # IO.inspect bytes_to_hex(contract_address)
    # IO.inspect ExW3.Contract.call(__MODULE__, :winner)
    # IO.inspect Ethereum.Contracts.EllipticoinStakingContract.winner()
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def deposit(amount, address),
    do:
      ExW3.Contract.send(__MODULE__, :deposit, [amount], %{
        from: address,
        gas: 6_721_975
      })

  def submit_block(block_hash, <<r::bytes-size(32), s::bytes-size(32), recovery_id::8-integer>>, address),
    do:
      ExW3.Contract.send(__MODULE__, :submitBlock, [block_hash, recovery_id + 27, r, s], %{
        from: address,
        gas: 6_721_975
      })

  def last_signature() do
    {:ok, v, r, s} = ExW3.Contract.call(__MODULE__, :lastSignature)

    {:ok, :binary.encode_unsigned(v) <> r <> s}
  end

  def winner(),
    do: ExW3.Contract.call(__MODULE__, :winner)

  def block_hash(),
    do: ExW3.Contract.call(__MODULE__, :blockHash)

  def totalStake(),
    do: ExW3.Contract.call(__MODULE__, :totalStake)
end
