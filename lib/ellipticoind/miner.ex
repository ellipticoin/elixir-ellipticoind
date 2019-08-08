defmodule Ellipticoind.Miner do
  require Logger
  use GenServer
  alias Ellipticoind.Repo
  alias Ellipticoind.Models.{Block, Transaction}
  alias Ellipticoind.{TransactionProcessor, Storage, Memory}

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
      :stopped ->
        nil

      %{
        block: new_block,
        memory_changeset: memory_changeset,
        storage_changeset: storage_changeset
      } ->
        hashfactor(new_block)
        |> case do
          :stopped ->
            nil

          proof_of_work_value ->
            new_block
            |> Map.put(:proof_of_work_value, proof_of_work_value)
            |> insert_block(memory_changeset, storage_changeset)
        end
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
  end

  defp insert_block(attributes, memory_changeset, storage_changeset) do
    changeset = Block.changeset(%Block{}, attributes)

    with {:ok, block} <- Repo.insert(changeset) do
      Memory.write_changeset(memory_changeset, block.number)
      Storage.write_changeset(storage_changeset, block.number)
      WebsocketHandler.broadcast(:blocks, block)
      P2P.broadcast(block)
      Logger.info("Mined block #{block.number}")
    end

    cast_mine_next_block()
  end
end
