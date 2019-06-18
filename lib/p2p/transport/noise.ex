defmodule P2P.Transport.Noise do
  require Logger
  use GenServer
  @crate "noise"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(options) do
    defaults = %{
      port: 4045,
      host: "0.0.0.0"
    }

    %{
      host: host,
      port: port,
      bootnodes: bootnodes
    } = Map.merge(defaults, options)

    port =
      Port.open(
        {:spawn_executable, path_to_executable()},
        [
          :stderr_to_stdout,
          args: [host, Integer.to_string(port)] ++ bootnodes
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
      apply(message.__struct__, :as_binary, [message])
      |> (&(apply(String.to_existing_atom("Elixir.P2P.Messages.#{message.__struct__ |> to_string() |> String.split(".") |> List.last()}"), :new, [[bytes: &1]]))).()
      |> (&(apply(String.to_existing_atom("Elixir.P2P.Messages.#{message.__struct__ |> to_string() |> String.split(".") |> List.last()}"), :encode, [&1]))).()
      |>(&Port.command(port, "#{Base.encode64(&1)}\n")).()
    {:noreply, state}
  end

  def handle_info({:EXIT, _port, reason}, _state) do
    Logger.error("Noise error #{inspect(reason)}")
    System.halt(1)
  end

  def handle_info({_port, {:data, message}}, state) do
    message =
      message
      |> to_string()
      |> String.trim()

    state =
      if String.contains?(message, "\n") do
        String.split(message, "\n")
        |> Enum.reduce(state, fn message, state ->
          handle_port_data(message, state)
        end)
      else
        handle_port_data(message, state)
      end

    {:noreply, state}
  end

  def handle_port_data("started", state) do
    %{state | started: true}
  end

  def handle_port_data("message:" <> message, state = %{subscribers: subscribers}) do
    case String.split(message, " ") do
      [address, type, raw_message] ->
        Enum.each(subscribers, fn subscriber ->
          message = apply(
            String.to_existing_atom("Elixir.P2P.Messages.#{type}"),
            :decode,
            [Base.decode64!(raw_message)]
          )
          |> Map.get(:bytes)
          |> Cbor.decode!()
          |> (&(struct(
            String.to_existing_atom("Elixir.Ellipticoind.Models.#{type}"),

            &1
          ))).()
          send(subscriber, {:p2p, address, message})
        end)

      message ->
        IO.puts("Invalid message:")
        IO.inspect(message)
    end

    state
  end

  def handle_port_data("log:" <> message, state) do
    Logger.info(message)
    state
  end

  def handle_port_data(data, state) do
    IO.puts(data)

    state
  end

  defp path_to_executable(), do: Application.app_dir(:ellipticoind, ["priv", "native", @crate])
end
