defmodule P2P.Transport.Noise do
  use GenServer
  @crate "noise"


  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(%{
        port: port,
        bootnodes: bootnodes,
  }) do
    port =
      Port.open({:spawn_executable, path_to_executable()},
      [
        :stderr_to_stdout,
        args: [
          "-p", Integer.to_string(port),
        ] ++ bootnodes,
      ]
      )

    {:ok,
     %{
       subscribers: [],
       port: port,
       started: false
     }}
  end

  def ensure_started(pid) do
    started = GenServer.call(pid, {:started?})
    if !started, do: ensure_started(pid)
  end

  def broadcast(message) do
    broadcast(__MODULE__, message)
  end

  def broadcast(pid, message) do
    GenServer.cast(pid, {:broadcast, message})
  end

  def subscribe(recipient_pid) do
    GenServer.call(__MODULE__, {:subscribe, recipient_pid})
  end

  def subscribe(pid, recipient_pid) do
    GenServer.call(pid, {:subscribe, recipient_pid})
  end

  def handle_call({:started?}, _from, state) do
    {:reply, state[:started], state}
  end

  def handle_call({:subscribe, pid}, _from, state) do
    state = update_in(state, [:subscribers], &[pid | &1])
    {:reply, nil, state}
  end

  def handle_cast({:broadcast, message}, state = %{port: port}) do
    # IO.puts "handle_cast :broadcast #{byte_size(message)}"
    Port.command(port, "#{Base.encode64(message)}\n")
    {:noreply, state}
  end

  def handle_info({_port, {:data, message}}, state) do
    state =
      message
      |> to_string()
      |> String.trim()
      |> handle_port_data(state)

    {:noreply, state}
  end

  def handle_port_data("started", state) do
    %{state | started: true}
  end

  def handle_port_data("message:" <> message, state = %{subscribers: subscribers}) do
    [address, message] = String.split(message, ":")

    Enum.each(subscribers, fn subscriber ->
      send(subscriber, {:p2p, address, Base.decode64!(message)})
    end)

    state
  end

  def handle_port_data(data, state) do
    IO.puts(data)

    state
  end

  defp path_to_executable(), do: Application.app_dir(:node, ["priv", "native", @crate])
end
