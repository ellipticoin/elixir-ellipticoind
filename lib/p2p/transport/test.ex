defmodule P2P.Transport.Test do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_state = %{bootnodes: bootnodes}) do

    {:ok,
     %{
       subscribers: [],
       peers: bootnodes,
     }}
  end

  def get_peers() do
    GenServer.call(__MODULE__, {:get_peers})
  end

  def receive(message) do
    GenServer.cast(__MODULE__, {:receive, message})
  end

  def subscribe(_pid), do: :ok

  def subscribe_to_test_broadcasts(pid) do
    GenServer.call(__MODULE__, {:subscribe_to_test_broadcasts, pid})
  end

  def broadcast(message) do
    GenServer.call(__MODULE__, {:broadcast, message})
  end

  def handle_call({:get_peers}, _from, %{peers: peers} = state) do
    {:reply, peers, state}
  end

  def handle_call({:subscribe_to_test_broadcasts, pid}, _from, state) do
    state = update_in(state, [:subscribers], &[pid | &1])
    {:reply, nil, state}
  end

  def handle_call(
        {:broadcast, message},
        _from,
        state = %{
          subscribers: subscribers
        }
      ) do
    Enum.each(subscribers, fn subscriber ->
      send(subscriber, {:p2p, nil, message})
    end)

    {:reply, nil, state}
  end

  def handle_cast(
        {:receive, message},
        state
      ) do
    spawn(fn ->
      P2P.receive(message)
    end)

    {:noreply, state}
  end
end
