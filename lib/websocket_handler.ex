defmodule WebsocketHandler do
  @behaviour :cowboy_websocket

  def init(req, state) do
    {:cowboy_websocket, req, state}
  end

  def websocket_init(state) do
    channel = state[:channel]

    :pg2.join("websocket::#{channel}", self())

    {:ok, state}
  end

  def terminate(_reason, _req, _state) do
    :ok
  end

  def websocket_handle(_frame, state) do
    {:ok, state}
  end

  def websocket_info({_channel, message}, state) do
    body = apply(message.__struct__, :to_json, [message])
    {:reply, {:text, body}, state}
  end

  def handle_info(_info, state) do
    {:ok, state}
  end

  def broadcast(channel, message) do
    Enum.each(:pg2.get_members("websocket::#{channel}"), fn pid ->
      send(pid, {channel, message})
    end)
  end
end
