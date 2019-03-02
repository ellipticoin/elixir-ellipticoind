defmodule P2P do
  require Logger
  alias Node.Models.Block
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(init_arg) do
    transport().subscribe(self())
    {:ok, %{}}
  end

  def broadcast(%{__struct__: _} = message),
    do:
      apply(message.__struct__, :as_binary, [message])
        |> broadcast()

  def broadcast(message),
    do:
      transport()
        |> apply(:broadcast, [message])

  def subscribe(),
    do:
      transport()
        |> apply(:subscribe)

  def receive(message) do
    Miner.cancel()

    Cbor.decode!(message)
      |> Block.apply()

    block = Cbor.decode!(message)
    Logger.info("Applied block #{block.number}")
  end

  def handle_info({:p2p, from, message}, state) do
    __MODULE__.receive(message)
    {:noreply, state}
  end

  defp transport(), do:
    Application.fetch_env!(:node, :p2p_transport)
end
