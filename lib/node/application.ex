defmodule Node.Application do
  use Application

  def start(_type, _args) do
    children = [
      Node.Repo,
      Supervisor.child_spec({Task, &WebsocketHandler.start/0}, id: WebsocketHandler),
      {Redis, name: Redis},
      Config.p2p_transport(),
      P2P,
      Config.cowboy(),
    ]

    children = if Application.fetch_env!(:node, :enable_miner) do
      children ++ [Miner]
    else
      children
    end

    opts = [strategy: :one_for_one, name: Node.Supervisor]

    supervisor = Supervisor.start_link(children, opts)
    SystemContracts.deploy()
    supervisor
  end
end
