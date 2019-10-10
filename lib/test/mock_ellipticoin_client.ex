defmodule Test.MockEllipticoinClient do
  alias Ellipticoind.Repo
  alias Ellipticoind.Views.BlockView
  use GenServer

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(_init_arg) do
    {:ok, %{blocks: []}}
  end

  def push_blocks(blocks) do
    GenServer.cast(__MODULE__, {:push_blocks, blocks})
  end

  def get_blocks() do
    GenServer.call(__MODULE__, {:get_blocks})
  end

  def get_block(block_number) do
    GenServer.call(__MODULE__, {:get_block, block_number})
  end

  def handle_cast({:push_blocks, blocks}, state) do
    state = Map.update!(state, :blocks, &(&1 ++ blocks))
    {:noreply, state}
  end

  def handle_call({:get_block, block_number}, _from, state = %{blocks: blocks}) do
    block = Enum.find(blocks, fn block -> block.number == block_number end)
    {:reply, block, state}
  end

  def handle_call({:get_blocks}, _from, state = %{blocks: blocks}) do
    {:reply, blocks, state}
  end
end
