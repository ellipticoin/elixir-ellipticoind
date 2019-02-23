defmodule StakingContractMonitor do
  require Logger
  use GenServer
  use Utils
  alias Ethereum.Contracts.EllipticoinStakingContract
  import EllipticoinStakingContract, only: [
    winner: 0,
    block_number: 0,
  ]

  import Ethereum.Helpers,
    only: [
      hex_to_int: 1,
      hex_to_bytes: 1
    ]

  alias Blacksmith.Models.Block

  def start_link(opts) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def init(state) do
    Ethereum.Helpers.subscribe_to_new_blocks()

    {:ok, state}
  end

  def handle_info(
        {:new_heads,
         %{
           "difficulty" => difficulty,
           "hash" => block_hash,
           "number" => block_number
         }},
        state
      ) do
    block_info = %{
      ethereum_difficulty: hex_to_int(difficulty),
      ethereum_block_hash: hex_to_bytes(block_hash),
      ethereum_block_number: hex_to_int(block_number),
      winner: winner(),
      number: block_number() + 1,
    }

    if Block.should_forge?(block_info) do
      Block.forge(block_info)
    end

    {:noreply, state}
  end
end
