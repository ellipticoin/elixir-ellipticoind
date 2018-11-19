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
      {TransactionProcessor, name: TransactionProcessor},
      {StakingContractMonitor, name: StakingContractMonitor},
      {P2P, name: P2P},
      {VM, name: VM},
      Plug.Adapters.Cowboy2.child_spec(
        scheme: :http,
        plug: Router,
        options: [
          dispatch: dispatch(),
          port: Application.fetch_env!(:blacksmith, :port)
        ]
      )
    ]

    opts = [strategy: :one_for_one, name: Blacksmith.Supervisor]
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
