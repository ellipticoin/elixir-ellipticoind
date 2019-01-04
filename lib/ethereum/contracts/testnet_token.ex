defmodule Ethereum.Contracts.TestnetToken do
  import Ethereum.Helpers
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(args) do
    abi = ExW3.load_abi(abi_file_name("TestnetToken"))
    ExW3.Contract.register(__MODULE__, abi: abi)

    {:ok, args}
  end

  def register() do
    abi = ExW3.load_abi(abi_file_name("TestnetToken"))
    ExW3.Contract.register(__MODULE__, abi: abi)
  end

  def at(address) do
    ExW3.Contract.at(__MODULE__, address)
  end

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
