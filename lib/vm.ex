defmodule VM do
  use GenServer
  use Rustler, otp_app: :blacksmith, crate: :vm_nif

  def current_block_hash(_redis_url), do: exit(:nif_not_loaded)
  def run(transaction), do: run(Application.fetch_env!(:blacksmith, :redis_url), transaction)
  def run(_redis_url, _transaction), do: exit(:nif_not_loaded)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    {:ok,
     Map.merge(state, %{
       redis_url: "redis://127.0.0.1/"
     })}
  end

  def set_contract_code(redis, address, contract_name, contract_code) do
    key = address <> Helpers.pad_bytes_right(contract_name)

    redis
    |> set_state(key, contract_code)
  end

  def set_state(redis, key, value) do
    Redix.command(redis, [
      "SET",
      key,
      value
    ])
  end
end
