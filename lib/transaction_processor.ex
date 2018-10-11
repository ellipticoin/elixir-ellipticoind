defmodule TransactionProccessor do
  @crate "transaction_processor"
  def start_link() do
    # Port.open({:spawn_executable, path_to_executable}, 
    #     [args: ["redis://127.0.0.1/"]])
  end

  def path_to_executable() do
    Path.expand("../priv/native/#{@crate}", __DIR__)
  end

  def mode() do
    if(Mix.env() == :prod, do: :release, else: :debug)
  end
end
