defmodule Ellipticoind.Miner do
  require Logger
  use GenServer
  alias Ellipticoind.Repo
  alias Ellipticoind.Models.{Block, Transaction}
  alias Ellipticoind.TransactionProcessor

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_init_arg) do
    SystemContracts.deploy()
    cast_mine_next_block()

    {:ok, nil}
  end

  def stop() do
    if miner_pid = Process.whereis(__MODULE__) do
      send(miner_pid, :stop)
    end
  end

  def cast_mine_next_block() do
    GenServer.cast(__MODULE__, {:mine_next_block})
  end

  def handle_info(:stop, state) do
    {:noreply, state}
  end

  def handle_cast({:mine_next_block}, state) do
    mine_next_block()
    {:noreply, state}
  end

  def mine_next_block() do
    mint()

    case TransactionProcessor.process_new_block() do
      :stopped -> nil
      new_block -> hashfactor(new_block)
    end
  end

  defp mint() do
    Transaction.post(%{
      contract_address: <<0::256>>,
      contract_name: :BaseToken,
      nonce: 0,
      function: :mint,
      arguments: [],
      sender: Configuration.public_key()
    })
  end

  defp hashfactor(new_block) do
    new_block
    |> Block.as_binary_pre_pow()
    |> Hashfactor.run()
    |> case do
      :stopped ->
        nil

      proof_of_work_value ->
        new_block
        |> Map.put(:proof_of_work_value, proof_of_work_value)
        |> insert_block()
    end
  end

  defp insert_block(attributes) do
    changeset = Block.changeset(%Block{}, attributes)

    with {:ok, block} <- Repo.insert(changeset) do
      WebsocketHandler.broadcast(:blocks, block)
      P2P.broadcast(block)
      Logger.info("Mined block #{block.number}")
    end

    cast_mine_next_block()
  end
end
