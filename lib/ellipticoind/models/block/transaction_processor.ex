defmodule Ellipticoind.Models.Block.TransactionProcessor do
  alias Ellipticoind.Models.{Block, Transaction}
  use GenServer
  @crate "transaction_processor"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(_init_arg) do
    port = Port.open({:spawn_executable, path_to_executable()},
      args: [
        Config.redis_url(),
        Config.rocksdb_path(),
      ]
    )

    {:ok, port}
  end

  def process_new_block() do
    GenServer.call(__MODULE__, {:process_new_block})
  end

  def set_storage(block_number, key, value) do
    GenServer.call(__MODULE__, {:set_storage, block_number, key, value})
  end

  def process(block, env \\ %{}) do
    GenServer.call(__MODULE__, {:process, block, env})
  end

  def changeset_hash() do
    {:ok, changeset} = Redis.fetch("changeset", <<>>)
    Redis.delete("changeset")
    Crypto.hash(changeset)
  end

  def revert_to(block_number) do
    for key <- Redis.get_set("memory_keys") do
      Redis.remove_range_by_reverse_score(
        key,
        block_number,
        "+inf"
      )
    end
  end

  def wait_until_done(port) do
    receive do
      :cancel ->
        Port.close(port)
        :cancelled

      {_port, {:data, message}} ->
        message
        |> List.to_string()
        |> handle_port_data(port)
    end
  end

  def handle_port_data("completed_transactions:" <> completed_transactions, _port) do
    completed_transactions
    |> String.trim("\n")
    |> String.split(" ")
    |> Enum.map(fn completed_transaction ->
      completed_transaction
      |> Base.decode64!()
      |> Cbor.decode!()
    end)
  end

  def handle_port_data("ok\n", _port), do: :ok
  def handle_port_data("\n", _port), do: nil

  def handle_port_data(message, port) do
    IO.write(message)
    wait_until_done(port)
  end

  def handle_call({:set_storage, block_number, key, value}, _from, port) do
    key_encoded = key |> Base.encode64()
    value_encoded = value |> Base.encode64()
    command = "set_storage " <> Integer.to_string(block_number) <> " " <> key_encoded <> " " <> value_encoded <> "\n"
    send(port, {self(), {:command, command}})
    {:reply, wait_until_done(port), port}
  end

  def handle_call({:process_new_block}, _from, port) do
    best_block = Block.best()

    env = %{
      block_number: if(best_block, do: best_block.number + 1, else: 0),
      block_winner: Config.public_key(),
      block_hash: <<>>
    }
    env_encoded = Cbor.encode(env) |> Base.encode64()
    command = "process_new_block " <> env_encoded <> " " <> Integer.to_string(Config.transaction_processing_time()) <> "\n"
    send(port, {self(), {:command, command}})

    return_value = case wait_until_done(port) do
      :cancelled ->
        :cancelled

      transactions ->
        Block.next_block_params()
        |> Map.merge(%{
          changeset_hash: changeset_hash(),
          transactions: transactions
        })
    end

    {:reply, return_value, port}
  end

  def handle_call({:process, block, env}, _from, port) do
    env =
      Map.merge(
        %{
          block_number: block.number,
          block_winner: block.winner,
          block_hash: block.hash
        },
        env
      )

    encoded_transactions =
      Enum.map(block.transactions, fn transaction ->
        transaction
        |> Transaction.with_code()
        |> Map.drop([
          :return_code,
          :return_value
        ])
        |> Cbor.encode()
      end)
    Redis.push("block", encoded_transactions)
    env_encoded = Cbor.encode(env) |> Base.encode64()
    command = "process_existing_block " <> env_encoded <> "\n"
    send(port, {self(), {:command, command}})
    return_value = case wait_until_done(port) do
      :cancelled ->
        :cancelled

      transactions ->
        changeset_hash = changeset_hash()

        %{
          changeset_hash: changeset_hash,
          transactions: transactions
        }
      end

      {:reply, return_value, port}
  end

  def path_to_executable(), do: Application.app_dir(:ellipticoind, ["priv", "native", @crate])
end
