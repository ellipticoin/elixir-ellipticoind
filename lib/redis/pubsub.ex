defmodule Redis.PubSub do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(_args) do
    connection_url = Application.fetch_env!(:node, :redis_url)
    {:ok, pubsub} = Redix.PubSub.start_link(connection_url)

    channels = [
      :hashcash_runner,
      :libp2p,
      :transaction_processor,
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

  def receive_message(channel, filter) do
    subscribe(channel, self())
    arguments = receive_message_loop(channel, filter)
    unsubscribe(channel, self())
    arguments
  end

  def receive_message_loop(channel, filter) do
    receive do
      {:pubsub, ^channel, message} ->
        if String.starts_with?(message, filter) do
          message
            |> String.split(" ")
            |> List.delete_at(0)
            |> Enum.map(&Base.decode64!/1)
        else
          receive_message_loop(channel, filter)
        end

      {:pubsub, ^channel, _message} ->
        receive_message_loop(channel, filter)
    end
  end

  def subscribe(channel, pid) do
    GenServer.call(__MODULE__, {:subscribe, channel, pid})
  end

  def unsubscribe(channel, pid) do
    GenServer.cast(__MODULE__, {:unsubscribe, channel, pid})
  end

  def handle_info({:redix_pubsub, _pid, :subscribed, %{channel: _channel}}, state) do
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, _pid, _from, :subscribed, %{channel: _channel}}, state) do
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, _pid, _from, :unsubscribed, %{channel: _channel}}, state) do
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

  def handle_call(
        {:subscribe, channel, pid},
        _from,
        state = %{pubsub: pubsub}
      ) do
    Redix.PubSub.subscribe(pubsub, channel, self())
    state = update_in(state, [:subscriptions, String.to_atom(channel)], &[pid | &1])
    {:reply, nil, state}
  end

  def handle_cast(
        {:unsubscribe, channel, pid},
        state = %{pubsub: pubsub}
      ) do
    Redix.PubSub.unsubscribe(pubsub, channel, self())
    state = update_in(state, [:subscriptions, String.to_atom(channel)], &List.delete(&1, pid))
    {:noreply, state}
  end
end
