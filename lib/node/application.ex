defmodule Node.Application do
  use Application

  def start(_type, _args) do
    :pg2.create("websocket::blocks")

    children = [
      Node.Repo,
      {Redis, name: Redis},
      {Redis.PubSub, name: Redis.PubSub},
      {TransactionPool, name: TransactionPool},
      {VM, name: VM},
      p2p_transport(),
      {P2P, name: P2P},
    ]

    opts = [strategy: :one_for_one, name: Node.Supervisor]

    if Application.fetch_env!(:node, :enable_miner) do
      children ++ [Miner]
    else
      children
    end
    |> List.insert_at(-1, cowboy_config())
    |> Supervisor.start_link(opts)
  end

  defp p2p_transport() do
    transport = Application.fetch_env!(:node, :p2p_transport)
    options = Application.fetch_env!(:node, transport)

    {transport, Enum.into(options, %{})}
  end

  defp cowboy_config() do
    if Application.get_env(:node, :https) do
      {Plug.Cowboy,
       scheme: :https,
       plug: Router,
       options: [
         dispatch: dispatch(),
         port: Application.fetch_env!(:node, :port),
         cipher_suite: :strong,
         otp_app: :node,
         keyfile: Application.fetch_env!(:node, :keyfile),
         certfile: Application.fetch_env!(:node, :certfile),
         # dhfile: Application.fetch_env!(:node, :dhfile)
       ]}
    else
      {Plug.Cowboy,
       scheme: :http,
       plug: Router,
       options: [
         dispatch: dispatch(),
         port: Application.fetch_env!(:node, :port)
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
