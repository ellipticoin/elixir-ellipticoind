defmodule Blacksmith.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      {VM, name: VM},
      {TransactionPool, name: TransactionPool},
      {Clock, name: Clock},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
