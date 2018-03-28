defmodule Mix.Tasks.Benchmark do
  @sender  Base.decode16!("509c3480af8118842da87369eb616eb7b158724927c212b676c41ce6430d334a", case: :lower)
  @receiver  Base.decode16!("027da28b6a46ec1124e7c3c33677b71f4ac4eae2485ff8cb33346aac54c11a30", case: :lower)
  use Mix.Task

  @shortdoc "Runs benchmarks"
  def run(_) do
    Application.ensure_all_started(:blacksmith)
    constructor(@sender, 1000000000)
    Benchee.run(%{
      "base_token_transfer"    => fn -> transfer(1, @receiver) end,
    }, time: 1)

    {:ok, balance}  = balance(@receiver)
    IO.puts "Receiver's balance after benchmark #{Cbor.decode(balance)}"
  end

  def balance(address) do
    GenServer.call(VM, %{
      rpc: Cbor.encode(%{
        method: :balance_of,
        params: [address],
      }),
      sender: @sender,
      nonce: 0
    })
  end

  def transfer(amount, recepient) do
    GenServer.call(VM, %{
      rpc: Cbor.encode(%{
        method: :transfer,
        params: [recepient, amount],
      }),
      sender: @sender,
      nonce: 0
    })
  end

  def constructor(sender, amount) do
    GenServer.call(VM, %{
      rpc: Cbor.encode(%{
        method: :constructor,
        params: [amount],
      }),
      sender: sender,
      nonce: 0
    })
  end
end
