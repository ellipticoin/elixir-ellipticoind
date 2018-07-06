defmodule Clock do
  @epoch 1530812550000
  @block_time 2_000
  use GenServer

  def start_link(name) do
    GenServer.start_link(__MODULE__, %{name: name})
  end

  def init(state) do
    schedule_tick()

    {:ok, state}
  end

  def time_since_last_block() do
    round(rem(:os.system_time(:milli_seconds) - @epoch, @block_time))
  end

  def handle_info(:tick, state) do
    schedule_tick()
    TransactionPool.forge_block()
    {:noreply, state}
  end

  defp schedule_tick() do
    offset = round(rem(:os.system_time(:milli_seconds) - @epoch, @block_time))
    Process.send_after(self(), :tick, @block_time - offset)
  end
end
