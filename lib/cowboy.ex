defmodule Cowboy do
  def dispatch do
    [
      {:_,
       [
         {"/websocket/blocks", WebsocketHandler, %{channel: :blocks}},
         {:_, Plug.Cowboy.Handler, {Router, []}}
       ]}
    ]
  end
end
