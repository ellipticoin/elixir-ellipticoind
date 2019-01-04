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
      Ethereum.Contracts.EllipticoinStakingContract,
      Ethereum.Contracts.TestnetToken,
      {TransactionProcessor, name: TransactionProcessor},
      {StakingContractMonitor, name: StakingContractMonitor},
      {P2P, name: P2P},
      {VM, name: VM},
      cowboy_config()
    ]

    opts = [strategy: :one_for_one, name: Blacksmith.Supervisor]
    ExW3.Contract.start_link()
    Supervisor.start_link(children, opts)
  end

  defp cowboy_config() do
    if Application.get_env(:blacksmith, :https) do
      {Plug.Cowboy,
       scheme: :https,
       plug: Router,
       options: [
         dispatch: dispatch(),
         port: Application.fetch_env!(:blacksmith, :port),
         cipher_suite: :strong,
         otp_app: :blacksmith,
         keyfile: Application.fetch_env!(:blacksmith, :keyfile),
         certfile: "priv/ssl/fullchain.pem",
         dhfile: "priv/ssl/ssl-dhparams.pem"
       ]}
    else
      {Plug.Cowboy,
       scheme: :http,
       plug: Router,
       options: [
         dispatch: dispatch(),
         port: Application.fetch_env!(:blacksmith, :port)
       ]}
    end
  end

  defp dispatch do
    [
      {:_,
       [
         {"/websocket/blocks", WebsocketHandler, %{channel: :blocks}},
         {:_, Plug.Cowboy.Handler, {Router, []}}
       ]}
    ]
  end
end
