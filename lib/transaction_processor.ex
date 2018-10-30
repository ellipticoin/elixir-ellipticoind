defmodule TransactionProccessor do
  use GenServer

  @crate "transaction_processor"

  def start_link(opts) do
    Port.open({:spawn_executable, path_to_executable},
      args: ["redis://127.0.0.1/"]
    )

    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    {:ok, redis} = Redix.start_link()

    {:ok,
      Map.merge(state, %{
        redis => redis,
      })
    }
  end

  def proccess_transactions() do
    start_proccessing_transactions()
    :timer.apply_after(15000, __MODULE__, :start_proccessing_transactions, [])
  end

  def start_proccessing_transactions do
    GenServer.cast(__MODULE__, {:start_proccessing_transactions})
  end

  def stop_proccessing_transactions do
    GenServer.cast(__MODULE__, {:start_proccessing_transactions})
  end

  def handle_cast({:start_proccessing_transactions}, state) do
    Redis.set_binary("continue_processing_transactions", true)
    {:noreply, state}
  end

  def handle_cast({:stop_proccessing_transactions}, state) do
    Redis.set_binary("continue_processing_transactions", false)
    {:noreply, state}
  end

  def path_to_executable() do
    Path.expand("../priv/native/#{@crate}", __DIR__)
  end

  def mode() do
    if(Mix.env() == :prod, do: :release, else: :debug)
  end
end
