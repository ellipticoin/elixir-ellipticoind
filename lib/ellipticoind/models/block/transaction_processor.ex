defmodule Ellipticoind.Models.Block.TransactionProcessor do
  use NativeModule
  alias Ellipticoind.Models.{Block, Transaction}

  def args() do
    [Config.redis_url(), Config.rocksdb_path()]
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

  def receive_native(port) do
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
    receive_native(port)
  end

  def handle_call({:set_storage, block_number, key, value}, _from, port) do
    call_native(port, :set_storage, [block_number, key, value])
    {:reply, receive_native(port), port}
  end

  def handle_call({:process_new_block}, _from, port) do
    env = %{
      block_number: Block.next_block_number(),
      block_winner: Config.public_key(),
      block_hash: <<>>
    }
    call_native(port, :process_new_block, [env, Config.transaction_processing_time()])

    case receive_native(port) do
      :cancelled ->
        {:reply, :cancelled, port}
      transactions ->
        block = Block.next_block_params()
        |> Map.merge(%{
          changeset_hash: changeset_hash(),
          transactions: transactions
        })
        {:reply, block, port}
    end
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
    return_value = case receive_native(port) do
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

  def changeset_hash() do
    {:ok, changeset} = Redis.fetch("changeset", <<>>)
    Redis.delete("changeset")
    Crypto.hash(changeset)
  end
end
