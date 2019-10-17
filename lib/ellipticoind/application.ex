defmodule Ellipticoind.Application do
  alias Ellipticoind.Syncer
  use Application

  def start(_type, _args) do
    children = [
      Ellipticoind.Repo,
      Supervisor.child_spec({Task, &WebsocketHandler.start/0}, id: WebsocketHandler),
      {Redis, name: Redis},
      {RocksDB, name: RocksDB},
      Configuration.p2p_transport(),
      P2P,
      Configuration.cowboy()
    ]

    children =
      if Application.fetch_env!(:ellipticoind, :enable_miner) do
        children ++ [Syncer]
      else
        children
      end

    opts = [strategy: :one_for_one, name: Ellipticoind.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
