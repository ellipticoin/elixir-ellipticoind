defmodule Ellipticoind.Miner do
  require Logger
  use GenServer
  alias Ellipticoind.Repo
  alias Ellipticoind.Models.{Block, Transaction}
  alias Ellipticoind.Views.BlockView
  alias Ellipticoind.{TransactionProcessor, Storage, Memory}
  @fast_sync_batch_size 100
  @ellipticoin_client Application.get_env(:ellipticoind, :ellipticoin_client)
  

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_init_arg) do
    SystemContracts.deploy()
    fast_sync()

    {:ok, %{
        mode: :fast_sync,
    }}
  end

  def stop() do
    if miner_pid = Process.whereis(__MODULE__) do
      send(miner_pid, :stop)
    end
  end

  def cast_mine_next_block() do
    GenServer.cast(__MODULE__, {:mine_next_block})
  end

  def fast_sync() do
    GenServer.cast(__MODULE__, {:fast_sync})
  end

  def get_next_block() do
    GenServer.cast(__MODULE__, {:get_next_block})
  end

  def get_mode() do
    GenServer.call(__MODULE__, :get_mode)
  end

  def handle_call(:get_mode, _from, %{mode: mode}= state) do
    {:reply, mode, state}
  end

  def handle_info(:stop, state) do
    {:noreply, state}
  end

  def handle_cast({:fast_sync}, state) do
    blocks = @ellipticoin_client.get_blocks()
    total_blocks = length(blocks)
    blocks_stream = Stream.map(Enum.reverse(blocks), &(&1))
    Enum.map(Stream.chunk_every(blocks_stream, @fast_sync_batch_size), fn blocks ->
      start_block_number = List.first(blocks).number
      end_block_number = List.last(blocks).number
      percentage_complete = round(end_block_number*100/total_blocks)

      blocks |> Enum.map(&Block.process_transactions/1)
      blocks |> Enum.map(&Repo.insert/1)
      Logger.info("Applied blocks #{start_block_number} to #{end_block_number} (#{percentage_complete}% complete)")
    end)
    IO.puts "get next block"
    get_next_block()

    {:noreply, state}
  end


  def handle_cast({:get_next_block}, state) do
    IO.puts "getting next block: ##{Block.next_block_number()}"
    block = @ellipticoin_client.get_block(Block.next_block_number())
    Block.process_transactions(block)
    Repo.insert(block)
    get_next_block()

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
      contract_address: <<0::256>> <> "BaseToken",
      nonce: 0,
      gas_limit: 100000000,
      function: :mint,
      arguments: [],
      sender: Configuration.public_key()
    })
  end

  defp hashfactor(new_block) do
    struct(%Block{}, new_block)
    |> BlockView.as_map_pre_pow()
    |> Cbor.encode()
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
