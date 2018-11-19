defmodule StakingContractMonitor do
  use GenServer
  use Utils
  alias Ethereum.Contracts.EllipticoinStakingContract
  alias Models.Block

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    Ethereum.Helpers.subscribe_to_new_blocks()

    {:ok, Map.put(state, :enabled,true)}
  end

  def disable() do
    GenServer.call(StakingContractMonitor, :disable)
  end

  def enable() do
    GenServer.call(StakingContractMonitor, :enable)
  end

  def handle_call(:enable, _from, state) do
    {:reply, nil, %{state | enabled: true}}
  end

  def handle_call(:disable, _from, state) do
    {:reply, nil, %{state | enabled: false}}
  end

  def handle_info(_block = %{"hash" => _hash}, state = %{enabled: true}) do
    {:ok, winner} = EllipticoinStakingContract.winner()

    if winner == Ethereum.Helpers.my_ethereum_address() do
      {:ok, block} = Block.forge(winner)
      P2P.broadcast_block(block)
      submit_block(block)
    end

    {:noreply, state}
  end

  def handle_info(_block, state) do
    {:noreply, state}
  end

  defp submit_block(block) do
    ethereum_private_key = Application.fetch_env!(:blacksmith, :ethereum_private_key)
    ethereum_address = ethereum_private_key
      |> Ethereum.Helpers.address_from_private_key()
      |> Ethereum.Helpers.bytes_to_hex()
    {:ok, signature} = EllipticoinStakingContract.last_signature()
                |> ok
                |> Ethereum.Helpers.sign(ethereum_private_key)

    EllipticoinStakingContract.submit_block(
      block.block_hash,
      signature,
      ethereum_address
    )
  end
end
