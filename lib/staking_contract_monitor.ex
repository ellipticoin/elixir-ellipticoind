defmodule StakingContractMonitor do
  use GenServer
  use Utils
  alias ABI.TypeDecoder

  def start_link(name) do
    GenServer.start_link(__MODULE__, %{name: name})
  end

  def init(state) do
    Ethereumex.WebSocketClient.eth_subscribe("newHeads")

    {:ok, state}
  end

  def handle_info(_block = %{"hash" => _hash}, state) do
    private_key = Application.fetch_env!(:blacksmith, :private_key)
    address = private_key_to_address(private_key)
    contract_address = Application.fetch_env!(:blacksmith, :staking_contract_address)

    winner = web3_call(contract_address, :winner, [], [:address])

    if winner == address do
      # Block.forge()
    end

    {:noreply, state}
  end

  defp web3_call(contract_address, method, args, return_type) do
    abi_encoded_data = ABI.encode("#{method}()", args) |> Base.encode16(case: :lower)

    {:ok, result_bytes} =
      Ethereumex.WebSocketClient.eth_call(%{
        data: "0x" <> abi_encoded_data,
        to: "0x" <> Base.encode16(contract_address)
      })

    result_bytes
    |> String.slice(2..-1)
    |> Base.decode16!(case: :lower)
    |> TypeDecoder.decode_raw(return_type)
    |> List.first()
  end
end
