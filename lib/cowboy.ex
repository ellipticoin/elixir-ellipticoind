defmodule Cowboy do
  use GenServer

  def init(args) do
    {:ok, args}
  end

  def start_link(_opts) do
    IO.puts "Listening on port #{port}..."
    { :ok, _ } = :cowboy.start_clear(:http,
      [{:port, port}],
      %{env: %{dispatch: dispatch_config()}}
    )
  end

  defp dispatch_config do
    :cowboy_router.compile([
      { :_,
        [
          {"/:nonce/:contract_name", RequestHandler, []},
          {"/:nonce/:address/:contract_name", RequestHandler, []}
        ]
      }
    ])
  end

  defp port do
    Application.get_env(:blacksmith, :port)
  end
end
