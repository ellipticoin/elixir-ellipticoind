defmodule TransactionProccessor do
  use GenServer

  @crate "transaction_processor"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end



  def init(state) do
    {:ok, redis} = Redix.start_link()
    Port.open({:spawn_executable, path_to_executable()},
      args: ["redis://127.0.0.1/"]
    )
    # Redis.subscribe("transaction_processor", "done", [__MODULE__, :done, []])

    {:ok,
      Map.merge(state, %{
        redis => redis,
      })
    }
  end

  def proccess_transactions(duration) do
    GenServer.cast(__MODULE__, {:proccess_transactions, duration})
  end

  def handle_cast({:proccess_transactions, duration}, state) do
    Redis.publish("transaction_processor", ["proccess_transactions", duration])
    {:noreply, state}
  end

  def handle_info({_port, {:data, message}}, state) do
    IO.write message
    {:noreply, state}
  end


  def path_to_executable() do
    Path.expand("../priv/native/#{@crate}", __DIR__)
  end

  def mode() do
    if(Mix.env() == :prod, do: :release, else: :debug)
  end
end
