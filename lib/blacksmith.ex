defmodule Blacksmith do
  import Supervisor.Spec
  use Application

  def start(_type, _args) do
    :pg2.create("websocket::blocks")

    children = [
      # Blacksmith.Supervisor,
      # Plug.Adapters.Cowboy2.child_spec(
      #   scheme: :http,
      #   plug: Router,
      #   options: [
      #     dispatch: dispatch(),
      #     port: Application.fetch_env!(:blacksmith, :port),
      #   ],
      # )
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    [
      {:_,
       [
         {"/websocket/blocks", WebsocketHandler, %{channel: :blocks}},
         {:_, Plug.Adapters.Cowboy2.Handler, {Router, []}}
       ]}
    ]
  end
end
