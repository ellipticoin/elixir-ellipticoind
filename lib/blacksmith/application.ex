defmodule Blacksmith.Application do
  import Supervisor.Spec
  use Application

  def start(_type, _args) do
    :pg2.create("websocket::blocks")

    children = [
      supervisor(Blacksmith.Repo, []),
      {Redis, name: Redis},
      {Redis.PubSub, name: Redis.PubSub},
      {TransactionPool, name: TransactionPool},
      {Ethereum.Contracts.EllipticoinStakingContract, name: Ethereum.Contracts.EllipticoinStakingContract},
      {TransactionProcessor, name: TransactionProcessor},
      {StakingContractMonitor, []},
      {P2P, name: P2P},
      {VM, name: VM},
      Plug.Adapters.Cowboy.child_spec(
        scheme: :http,
        plug: Router,
        options: [
          dispatch: dispatch(),
          port: Application.fetch_env!(:blacksmith, :port)
        ]
      )
    ]

    opts = [strategy: :one_for_one, name: Blacksmith.Supervisor]
    ExW3.Contract.start_link()
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    [
      {:_,
       [
         {"/websocket/blocks", WebsocketHandler, %{channel: :blocks}},
         {:_, Plug.Adapters.Cowboy2.Handler, {Router, []}}
       ]}
    ]
  end
end
