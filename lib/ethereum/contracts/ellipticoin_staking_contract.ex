defmodule Ethereum.Contracts.EllipticoinStakingContract do
  def deposit(amount, address),
    do:
      ExW3.Contract.send(__MODULE__, :deposit, [amount], %{
        from: address,
        gas: 6_721_975
      })

  def winner(),
    do: ExW3.Contract.call(__MODULE__, :winner)

  def totalStake(),
    do: ExW3.Contract.call(__MODULE__, :totalStake)
end
