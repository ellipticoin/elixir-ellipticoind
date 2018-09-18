# defmodule Blacksmith.Supervisor do
#   use Supervisor
#
#   def start_link(opts) do
#     opts = [strategy: :one_for_one, name: Blacksmith.Supervisor]
#     Supervisor.start_link(__MODULE__, :ok, opts)
#   end
#
#   # def init(:ok) do
#   #   children = [
#   #     supervisor(Repo, []),
#   #     {Db.Redis, name: Db.Redis},
#   #     {VM, name: VM},
#   #     {TransactionPool, name: TransactionPool},
#   #     {Clock, name: Clock},
#   #   ]
#   #
#   #   Supervisor.init(children, strategy: :one_for_one)
#   # end
# end
