defmodule Ellipticoind.Application do
  alias Ellipticoind.Miner
  alias Ellipticoind.Models.Block.TransactionProcessor
  use Application

  def start(_type, _args) do
    children = [
      Ellipticoind.Repo,
      Supervisor.child_spec({Task, &WebsocketHandler.start/0}, id: WebsocketHandler),
      {Redis, name: Redis},
      {RocksDB, name: RocksDB},
      {TransactionProcessor, name: TransactionProcessor},
      {Hashfactor, name: Hashfactor},
      Config.p2p_transport(),
      P2P,
      Config.cowboy()
    ]

    children =
      if Application.fetch_env!(:ellipticoind, :enable_miner) do
        children ++ [Miner]
      else
        children
      end

    opts = [strategy: :one_for_one, name: Ellipticoind.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
