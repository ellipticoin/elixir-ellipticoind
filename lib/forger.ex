defmodule Forger do
  @one_second 1_000
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    {:ok, redis} = Redix.start_link()

    {:ok,
     %{
       redis: redis,
       auto_forge: false,
       subscribers: []
     }}
  end

  def handle_cast({:subscribe, pid}, state = %{subscribers: subscribers}) do
    state = Map.update!(state, :subscribers, &[pid | &1])
    {:noreply, state}
  end

  def enable_auto_forging() do
    GenServer.cast(__MODULE__, {:enable_auto_forging})
  end

  def disable_auto_forging() do
    GenServer.cast(__MODULE__, {:disable_auto_forging})
  end

  def handle_cast({:enable_auto_forging}, state) do
    GenServer.cast(self(), :auto_forge)
    {:noreply, %{state | auto_forge: true}}
  end

  def handle_cast({:disable_auto_forging}, state) do
    {:noreply, %{state | auto_forge: false}}
  end

  def handle_cast(:auto_forge, state = %{redis: redis, auto_forge: auto_forge}) do
    case Redix.command(redis, ["BRPOP", "transactions::done", 1]) do
      {:ok, ["transactions::done", receipt]} ->
        GenServer.cast(self(), {:forge, [receipt]})

      {:ok, nil} ->
        nil
    end

    if auto_forge do
      GenServer.cast(self(), :auto_forge)
    end

    {:noreply, state}
  end

  def handle_cast({:forge, receipts}, state = %{subscribers: subscribers}) do
    Enum.each(subscribers, fn subscriber ->
      send(subscriber, receipts)
    end)

    state = Map.put(state, :subscribers, [])
    {:noreply, state}
  end

  def handle_cast({:forge, receipts}, state) do
    {:noreply, state}
  end

  def wait_for_block(pid) do
    GenServer.cast(__MODULE__, {:subscribe, pid})

    receive do
      receipts -> receipts
    end
  end
end
