defmodule TransactionProccessor do
  use GenServer

  @crate "transaction_processor"
  def start_link(opts) do
    Port.open({:spawn_executable, path_to_executable},
      args: ["redis://127.0.0.1/"]
    )

    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(_args) do
    {:ok, nil}
  end

  def path_to_executable() do
    Path.expand("../priv/native/#{@crate}", __DIR__)
  end

  def mode() do
    if(Mix.env() == :prod, do: :release, else: :debug)
  end
end
