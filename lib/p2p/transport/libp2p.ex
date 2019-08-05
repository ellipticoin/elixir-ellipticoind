defmodule P2P.Transport.LibP2P do
  use GenServer
  @crate "libp2p"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(
        options = %{
          port: port
        }
      ) do
    libp2p_address = "/ip4/0.0.0.0/tcp/#{port}"

    bootnodes =
      Configuration.bootnodes()
      |> Enum.join(",")

    private_key =
      (Map.get(options, :private_key) || Configuration.private_key())
      |> Base.encode64()

    port =
      Port.open({:spawn_executable, path_to_executable()},
        args: [private_key, libp2p_address, bootnodes]
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
      send(subscriber, {:libp2p, address, Base.decode64!(message)})
    end)

    state
  end

  def handle_port_data(data, state) do
    IO.puts(data)

    state
  end

  defp path_to_executable(), do: Application.app_dir(:ellipticoind, ["priv", "native", @crate])
end
