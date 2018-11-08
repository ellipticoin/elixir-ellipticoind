defmodule Ethereum.Contracts.TestnetToken do
  def mint(address, amount),
    do:
      ExW3.Contract.send(__MODULE__, :mint, [ExW3.to_decimal(address), amount], %{
        from: address,
        gas: 6_721_975
      })

  def approve(address, amount, from),
    do:
      ExW3.Contract.send(__MODULE__, :approve, [ExW3.to_decimal(address), amount], %{
        from: from,
        gas: 6_721_975
      })
end
