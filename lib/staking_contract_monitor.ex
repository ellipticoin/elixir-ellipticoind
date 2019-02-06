defmodule StakingContractMonitor do
  require Logger
  use GenServer
  use Utils
  alias Crypto.RSA
  alias Ethereum.Contracts.EllipticoinStakingContract
  alias Blacksmith.Models.Block

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    Ethereum.Helpers.subscribe_to_new_blocks()

    {:ok, Map.put(state, :enabled, true)}
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

  def handle_info(_block = %{"hash" => _hash, "number" => _number}, state = %{enabled: true}) do
    winner = EllipticoinStakingContract.winner()
    block_number = EllipticoinStakingContract.block_number()

    Logger.info("Block ##{block_number} won by #{Base.encode16(winner, case: :lower)}")
    if EllipticoinStakingContract.winner() == Ethereum.Helpers.my_ethereum_address() do
      {:ok, block} =
        Block.forge(%{
          winner: winner,
          block_number: block_number + 1
        })

      P2P.broadcast_block(block)
      submit_block(block)
      WebsocketHandler.broadcast(:blocks, block)
    end

    {:noreply, state}
  end

  def handle_info(_block, state) do
    {:noreply, state}
  end

  defp submit_block(block) do
    block_hash = block.block_hash
    block_number = block.number
    ethereum_private_key = Application.fetch_env!(:blacksmith, :ethereum_private_key)

    ethereum_address =
      ethereum_private_key
      |> Ethereum.Helpers.private_key_to_address()
      |> Ethereum.Helpers.bytes_to_hex()

    last_signature = EllipticoinStakingContract.last_signature()

    rsa_key =
      Application.get_env(:blacksmith, :private_key)
      |> RSA.parse_pem()

    signature = RSA.sign(last_signature, rsa_key)

    EllipticoinStakingContract.submit_block(block_number, block_hash, signature)
  end
end
