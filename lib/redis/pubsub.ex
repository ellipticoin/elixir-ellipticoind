defmodule Redis.PubSub do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(_args) do
    connection_url = Application.fetch_env!(:blacksmith, :redis_url)
    {:ok, pubsub} = Redix.PubSub.start_link(connection_url)

    channels = [
      :transaction_processor
    ]

    subscriptions =
      Enum.map(channels, fn channel ->
        {channel, []}
      end)
      |> Enum.into(%{})

    {:ok,
     %{
       pubsub: pubsub,
       subscriptions: subscriptions
     }}
  end

  def subscribe(channel, pid) do
    GenServer.cast(__MODULE__, {:subscribe, channel, pid})
  end

  def handle_info({:redix_pubsub, _pid, :subscribed, %{channel: _channel}}, state) do
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, _pid, _from, :subscribed, %{channel: _channel}}, state) do
    {:noreply, state}
  end

  def handle_info(
        {:redix_pubsub, _pid, _from, :message, %{channel: channel, payload: payload}},
        state = %{subscriptions: subscriptions, pubsub: _pubsub}
      ) do
    Enum.each(subscriptions[String.to_atom(channel)], fn subscriber ->
      send(subscriber, {:pubsub, channel, payload})
    end)

    {:noreply, state}
  end

  def handle_cast(
        {:subscribe, channel, pid},
        state = %{pubsub: pubsub}
      ) do
    Redix.PubSub.subscribe(pubsub, channel, self())
    state = update_in(state, [:subscriptions, String.to_atom(channel)], &[pid | &1])
    {:noreply, state}
  end
end
