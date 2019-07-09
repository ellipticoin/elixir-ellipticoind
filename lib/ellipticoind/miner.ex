defmodule Ellipticoind.Miner do
  require Logger
  use GenServer
  alias Ellipticoind.Repo
  alias Ellipticoind.Models.{Block, Transaction}
  alias Ellipticoind.TransactionProcessor

  def start_link([]), do: start_link()

  def start_link() do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_init_arg) do
    SystemContracts.deploy()
    mine()

    {:ok, nil}
  end


  def mine() do
    GenServer.cast(__MODULE__, {:mine})
  end

  def handle_cast({:mine}, state) do
    process_new_block()
    {:noreply, state}
  end

  def process_new_block() do
    Transaction.post(%{
      contract_address: <<0::256>>,
      contract_name: :BaseToken,
      nonce: 0,
      function: :mint,
      arguments: [],
      sender: Configuration.public_key()
    })

    case TransactionProcessor.process_new_block() do
      :cancel -> mine()
      new_block -> hashfactor(new_block)
    end
  end

  defp hashfactor(new_block) do
    new_block
    |> Block.as_binary_pre_pow()
    |> Hashfactor.run()
    |> case do
      :cancelled -> mine()
      proof_of_work_value ->
        Map.put(new_block, :proof_of_work_value, proof_of_work_value)
        |> insert_block()
    end
  end

  defp insert_block(attributes) do
    block =
      Block.changeset(%Block{}, attributes)
      |> Repo.insert!()

    WebsocketHandler.broadcast(:blocks, block)
    P2P.broadcast(block)

    Logger.info("Mined block #{block.number}")
    mine()
  end
end
