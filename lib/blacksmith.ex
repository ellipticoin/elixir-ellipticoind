defmodule Blacksmith do
  use Application

  def start(_type, _args) do
    children = [
      Blacksmith.Supervisor,
      Plug.Adapters.Cowboy.child_spec(
        scheme: :http,
        plug: Router,
        options: [
          port: Application.fetch_env!(:blacksmith, :port),
        ],
      )
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
