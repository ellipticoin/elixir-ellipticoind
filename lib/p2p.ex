defmodule P2P do
  require Logger
  alias Ellipticoind.Models.Block
  alias Ellipticoind.Miner
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(_init_arg) do
    transport().subscribe(self())
    {:ok, %{}}
  end

  def broadcast(%{__struct__: _} = message),
    do:
      apply(message.__struct__, :as_binary, [message])
      |> (&(apply(String.to_existing_atom("Elixir.P2P.Messages.#{message.__struct__ |> to_string() |> String.split(".") |> List.last()}"), :new, [[bytes: &1]]))).()
      |> (&(apply(String.to_existing_atom("Elixir.P2P.Messages.#{message.__struct__ |> to_string() |> String.split(".") |> List.last()}"), :encode, [&1]))).()
      |> (&(apply(transport(), :broadcast, [&1]))).()


  def subscribe(),
    do:
      transport()
      |> apply(:subscribe)

  def receive(message) do
    Miner.cancel()
    Block.apply(message)
    Logger.info("Applied block #{message.number}")
  end

  def handle_info({:p2p, _from, message}, state) do
    __MODULE__.receive(message)
    {:noreply, state}
  end

  defp transport(), do: Application.fetch_env!(:ellipticoind, :p2p_transport)
end
