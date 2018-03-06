defmodule Cowboy do
  use GenServer

  def start_link(opts) do
    { :ok, _ } = :cowboy.start_clear(:http,
      [{:port, 4047}],
      %{env: %{dispatch: dispatch_config()}}
    )
  end

  defp dispatch_config do
    :cowboy_router.compile([
      { :_,
        [
          {"/", RequestHandler, []}
        ]
      }
    ])
  end
end
