defmodule TransactionProcessor do
  alias Node.Models.{Block, Transaction}

  @crate "transaction_processor"

  def init(state) do
    redis_connection_url = Application.fetch_env!(:node, :redis_url)

    Port.open({:spawn_executable, path_to_executable()},
      args: [redis_connection_url]
    )

    {:ok, state}
  end

  def process_new_block() do
    transaction_processing_time = Application.fetch_env!(:node, :transaction_processing_time)
    redis_connection_url = Application.fetch_env!(:node, :redis_url)
    port = run([
      "process_new_block",
      redis_connection_url,
      Integer.to_string(transaction_processing_time),
    ])

    receive do
      :cancel ->
        Port.close(port)
        :cancelled
      {_port, {:data, '\n'}} -> nil
      message -> IO.inspect message
    end

    new_block_from_redis()
  end

  def process(transactions) do
    redis_connection_url = Application.fetch_env!(:node, :redis_url)
    encoded_transactions = Enum.map(transactions, fn transaction ->
      transaction
        |> Transaction.with_code()
        |> Cbor.encode()
    end)
    Redis.push("block", encoded_transactions)
    _port = run([
      "process_existing_block",
      redis_connection_url,
    ])

    receive do
      {_port, {:data, '\n'}} -> nil
      message -> IO.inspect message
    end
    {:ok, changeset} = Redis.fetch("changeset", <<>>)

    %{
      changeset_hash: Crypto.hash(changeset),
      transactions: done_transactions(),
    }
  end

  def new_block_from_redis() do
    {:ok, changeset} = Redis.fetch("changeset", <<>>)
    Block.next_block_params()
    |> Map.merge(%{
      changeset_hash: Crypto.hash(changeset),
      transactions: done_transactions(),
    })
  end

  def done_transactions do
    {:ok, transactions} = Redis.get_list("transactions::done")
    {:ok, results} = Redis.get_list("results")

    Enum.zip(transactions, results)
      |> Enum.map(fn {transaction_bytes, result_bytes} ->
        <<return_code::little-integer-size(32), return_value::binary>> = result_bytes
        transaction = Cbor.decode!(transaction_bytes)
        Cbor.decode!(transaction_bytes)
          |> Map.merge(
            %{
            arguments: transaction.arguments,
            return_code: return_code,
            return_value: Cbor.decode!(return_value)
          })
          |> Map.delete(:code)
      end)
  end

  # Ignore all other pubsub messages
  def handle_info({:pubsub, "transaction_processor", _}, state) do
    {:noreply, state}
  end

  def handle_info({_port, {:data, message}}, state) do
    IO.write(message)
    {:noreply, state}
  end

  defp run(args) do
    Port.open({:spawn_executable, path_to_executable()}, args: args)
  end

  def path_to_executable(), do: Application.app_dir(:node, ["priv", "native", @crate])

  def mode() do
    if(Mix.env() == :prod, do: :release, else: :debug)
  end
end
