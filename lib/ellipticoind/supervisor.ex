defmodule Ellipticoind.Supervisor do
  use Supervisor

  def start_link(_opts) do
    opts = [strategy: :one_for_one, name: Ellipticoind.Supervisor]
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      # supervisor(Repo, []),
      # {Db.Redis, name: Db.Redis},
      # {VM, name: VM},
      # {VM, name: VM},
      # {TransactionPool, name: TransactionPool},
      # {Clock, name: Clock},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
