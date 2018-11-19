defmodule Ethereum.Contracts.EllipticoinStakingContract do
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
