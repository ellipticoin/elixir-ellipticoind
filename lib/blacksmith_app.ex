defmodule BlacksmithApp do
  def start(_type, _args) do
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
