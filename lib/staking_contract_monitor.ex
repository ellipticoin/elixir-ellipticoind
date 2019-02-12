defmodule StakingContractMonitor do
  require Logger
  use GenServer
  use Utils
  alias Ethereum.Contracts.EllipticoinStakingContract
  alias Blacksmith.Models.Block

  def start_link(opts) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def init(state) do
    Ethereum.Helpers.subscribe_to_new_blocks()

    {:ok, state}
  end

  def handle_info({:new_heads, _block}, state) do
    if winner?() do
      Block.forge()
    end

    {:noreply, state}
  end

  defp winner?(), do:
    EllipticoinStakingContract.winner() == Ethereum.Helpers.my_ethereum_address()
end
