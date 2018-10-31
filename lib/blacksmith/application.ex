defmodule Blacksmith.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec
    Process.flag(:trap_exit, true)
    # List all child processes to be supervised
    :pg2.create("websocket::blocks")

    children = [
      supervisor(Blacksmith.Repo, []),
      {Redis, name: Redis},
      {Redis.PubSub, name: Redis.PubSub},
      {TransactionPool, name: TransactionPool},
      {TransactionProccessor, name: TransactionProccessor},
      {StakingContractMonitor, name: StakingContractMonitor},
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

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Blacksmith.Supervisor]
    Supervisor.start_link(children, opts)
    # Do the work you desire here
  end
  def handle_info(payload, state) do
    IO.inspect payload
    {:noreply, state}
  end
  def handle_call(payload, _from, state) do
    IO.inspect payload
    {:noreply, state}
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
