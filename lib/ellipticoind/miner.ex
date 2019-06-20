defmodule Ellipticoind.Miner do
  require Logger
  use GenServer
  alias Ellipticoind.Repo
  alias Ellipticoind.BlockIndex
  alias Ellipticoind.Models.{Block, Transaction}
  alias Ellipticoind.TransactionProcessor

  def start_link([]), do: start_link()

  def start_link() do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_init_arg) do
    SystemContracts.deploy()
    mining_loop()

    {:ok, nil}
  end

  @doc """
  Cancels mining of the current block. This is called when a new block
  comes in.
  """
  def cancel() do
    TransactionProcessor.cancel()

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
    Transaction.post(%{
      contract_address: <<0::256>>,
      contract_name: :BaseToken,
      nonce: 0,
      function: :mint,
      arguments: [],
      sender: Config.public_key()
    })

    case TransactionProcessor.process_new_block() do
      :cancelled -> handle_cancel()
      :ok -> handle_cancel()
      new_block -> hashfactor(new_block)
    end
  end

  defp handle_cancel() do
    BlockIndex.revert_to(Block.next_block_number() - 1)
    mining_loop()
  end

  defp hashfactor(new_block) do
    new_block
    |> Block.as_binary_pre_pow()
    |> Hashfactor.run()
    |> case do
      :cancelled ->
        handle_cancel()

      proof_of_work_value ->
        Map.put(new_block, :proof_of_work_value, proof_of_work_value)
        |> insert_block()
    end
  end

  defp insert_block(attributes) do
    block = Block.changeset(%Block{}, attributes)
    |> Repo.insert!()
    WebsocketHandler.broadcast(:blocks, block)
    P2P.broadcast(block)
    Logger.info("Mined block #{block.number}")
    mining_loop()
  end
end
