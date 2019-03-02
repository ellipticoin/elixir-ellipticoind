defmodule Miner do
  require Logger
  use GenServer
  alias Node.Models.Block

  def start_link([]), do: start_link()
  def start_link() do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_init_arg) do
    mining_loop()
    {:ok, nil}
  end

  @doc """
  Cancels mining of the current block. This is called when a new block
  comes in.
  """
  def cancel() do
    if Enum.member?(Process.registered(), __MODULE__) do
      send(__MODULE__, :cancel)
    end
  end

  def mining_loop() do
    GenServer.cast(__MODULE__, {:mining_loop})
  end

  def handle_info(:cancel, state) do
    {:noreply, state}
  end

  def handle_cast({:mining_loop}, state) do
    process_new_block()
    {:noreply, state}
  end

  defp process_new_block() do
    case TransactionProcessor.process_new_block() do
      :cancelled -> mining_loop()
      new_block -> hashfactor(new_block)
    end
  end

  defp hashfactor(new_block) do
    new_block
      |> Block.as_binary_pre_pow()
      |> Hashfactor.run()
      |> case do
        :cancelled -> mining_loop()
        proof_of_work_value  -> insert(new_block, proof_of_work_value)
      end
  end

  defp insert(new_block, proof_of_work_value) do
    new_block = Map.put(new_block, :proof_of_work_value, proof_of_work_value)

    block = Block.insert(new_block)
    P2P.broadcast(block)
    Logger.info("Mined block #{new_block.number}")
    mining_loop()
  end
end
