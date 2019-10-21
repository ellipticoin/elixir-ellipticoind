defmodule P2P do
  require Logger
  alias Ellipticoind.Syncer
  alias Ellipticoind.Repo
  alias Ellipticoind.Models.{Block, Transaction}
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(_init_arg) do
    transport().subscribe(self())
    {:ok, %{}}
  end

  def get_peers() do
    transport().get_peers()
  end

  def broadcast(message),
    do: apply(transport(), :broadcast, [message])

  def subscribe(),
    do: apply(transport(), :subscribe)

  def receive(message) do
    case message.__struct__ do
      Block -> if message.number == Block.next_block_number() do
        Block.apply(message)
        Repo.insert(message)
      end
      Transaction -> Transaction.post(message)
    end
  end

  def handle_info(:stop, state) do
    {:noreply, state}
  end

  def handle_info({:p2p, message}, state) do
    __MODULE__.receive(message)
    {:noreply, state}
  end

  defp transport(), do: Application.fetch_env!(:ellipticoind, :p2p_transport)
end
