defmodule P2P.Transport.Libp2p do
  alias P2P.Messages
  require Logger
  use GenServer
  @module "libp2p"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(options) do
    defaults = %{
      port: 4045,
      ip: "0.0.0.0"
    }

    %{
      ip: ip,
      port: port,
      bootnodes: bootnodes
    } = Map.merge(defaults, options)

    port =
      Port.open(
        {:spawn_executable, path_to_executable()},
        [
          :stderr_to_stdout,
          args: [Base.encode16(:binary.part(Configuration.private_key(), 0, 32)), ip, Integer.to_string(port)] ++ bootnodes
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

  def handle_cast({:broadcast, struct}, state = %{port: port}) do
    message = Messages.type(struct) <> " "<> Messages.encode(struct)

    Port.command(port, <<byte_size(message)::unsigned-32>> <> message)

    {:noreply, state}
  end

  def handle_info({:EXIT, _port, reason}, _state) do
    Logger.error("Libp2p error #{inspect(reason)}")
    System.halt(1)
  end

  def handle_info({_port, {:data, data}}, state) do
    state = split_messages(:binary.list_to_bin(data))
    |>Enum.reduce(state, &handle_port_data/2)
    {:noreply, state}
  end

  def handle_port_data("started", state) do
    %{state | started: true}
  end


  def handle_port_data("message:" <> message, state = %{subscribers: subscribers}) do
    case String.split(message, " ", parts: 2) do
      [type, raw_message] ->
        Enum.each(subscribers, fn subscriber ->
          message = Messages.decode(raw_message, type)

          send(subscriber, {:p2p, message})
        end)

     message ->
        IO.puts("Invalid message:")
        IO.inspect(message)
    end

    state
  end

  def handle_port_data("log:" <> message, state) do
    IO.puts message
    state
  end

  def handle_port_data(data, state) do
    IO.inspect(data)

    state
  end

  def split_messages(
    <<
      message_size::unsigned-32,
      message_data :: binary>> = full_message,
    messages \\ []
  ) do
    cond do
      byte_size(message_data) == message_size  ->
        [message_data| messages]
      byte_size(message_data) < message_size ->
        split_messages(continue_receiving(message_size + 4, full_message), messages)
      byte_size(message_data) > message_size ->
        <<message_body::binary-size(message_size), message_data::binary>> = message_data
        split_messages(message_data, messages ++ [message_body])
    end
  end

  def continue_receiving(length, full_message\\<<>>) do
    receive do
      {_port, {:data, new_part}} ->
        new_part_bin = :binary.list_to_bin(new_part)
        if byte_size(full_message) + byte_size(new_part_bin) == length do
          full_message <> new_part_bin
        else
          continue_receiving(length, full_message <> new_part_bin)
      end 
    end
  end

  defp path_to_executable(), do: Application.app_dir(:ellipticoind, ["priv", "native", @module])
end
