defmodule Redis.PubSub do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(_args) do
    {:ok, pubsub} = Redix.PubSub.start_link()
    channels = [
      :transaction_processor,
    ]

    subscriptions = Enum.map(channels, fn(channel) ->
      {channel, []}
    end)
      |> Enum.into(%{})
    {:ok, %{
      pubsub: pubsub,
      subscriptions: subscriptions,
    }}
  end

  def subscribe(channel, pid) do
    GenServer.cast(__MODULE__, {:subscribe, channel, pid})
  end

  def handle_info({:redix_pubsub, pid, :subscribed, %{channel: channel}}, state) do
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, pid, :message, %{channel: channel, payload: payload}}, state = %{subscriptions: subscriptions, pubsub: pubsub}) do
    Enum.each(subscriptions[String.to_atom(channel)], fn subscriber ->
      send(subscriber, {:pubsub, channel, payload})
    end)
    {:noreply, state}
  end

  def handle_cast({:subscribe, channel, pid}, state = %{subscriptions: subscriptions, pubsub: pubsub}) do
    Redix.PubSub.subscribe(pubsub, channel, self())
    state = update_in(state, [:subscriptions, String.to_atom(channel)], &[pid | &1])
    {:noreply, state}
  end
end
