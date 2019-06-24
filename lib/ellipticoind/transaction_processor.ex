defmodule Ellipticoind.TransactionProcessor do
  use NativeModule
  alias Ellipticoind.Models.{Block, Transaction}

  def args() do
    [Config.redis_url(), Config.rocksdb_path()]
  end

  def cancel() do
    send(__MODULE__, :cancel)
  end

  def set_storage(block_number, key, value) do
    GenServer.call(__MODULE__, {:set_storage, block_number, key, value})
  end

  def process(block, env \\ %{}) do
    cancel()
    GenServer.call(__MODULE__, {:process, block, env})
  end

  def process_new_block() do
    cancel()
    GenServer.call(__MODULE__, {:process_new_block})
  end

  def handle_info({_port, {:data, _message}}, port) do
    {:noreply, port}
  end

  def handle_info(:cancel, state) do
    {:noreply, state}
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
      :cancel ->
        {:reply, :cancelled, port}

      :ok ->
        {:reply, :cancelled, port}

      transactions ->
        block =
          Block.next_block_params()
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

    call_native(port, :process_existing_block, [
      env,
      Enum.map(block.transactions, &Transaction.as_map/1)
    ])

    case receive_native(port) do
      :cancel ->
        {:reply, :cancelled, port}

      :ok ->
        {:reply, :cancelled, port}

      transactions ->
        return_value = %{
          changeset_hash: changeset_hash(),
          transactions: transactions
        }

        {:reply, return_value, port}
    end
  end

  def receive_native(port) do
    case receive_cancel_or_message(port) do
      :cancel ->
        :cancel

      message ->
        case List.to_string(message) do
          "debug:" <> message -> IO.puts message
          message -> message
            |> String.trim("\n")
            |> Base.decode64!()
            |> Cbor.decode!()
        end
    end
  end

  def receive_cancel_or_message(port, message \\ '') do
    receive do
      :cancel ->
        :cancel

      {_port, {:data, message_part}} ->
        if length(message_part) > 65535 do
          receive_cancel_or_message(port, Enum.concat(message, message_part))
        else
          Enum.concat(message, message_part)
        end
    end
  end

  def changeset_hash() do
    {:ok, changeset} = Redis.fetch("changeset", <<>>)
    Redis.delete("changeset")
    Crypto.hash(changeset)
  end
end
