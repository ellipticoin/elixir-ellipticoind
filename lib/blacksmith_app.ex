defmodule BlacksmithApp do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(GRPC.Server.Supervisor, [{Blacksmith.Server, 4047}])
    ]

    opts = [strategy: :one_for_one, name: BlacksmithApp]
    Supervisor.start_link(children, opts)
  end
end
