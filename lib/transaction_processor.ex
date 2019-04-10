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
    env = %{
      block_number: 1,
      block_winner: Config.public_key(),
      block_hash: <<>>,
    }
    port = run([
      redis_connection_url,
      "process_new_block",
      Cbor.encode(env) |> Base.encode16,
      Integer.to_string(transaction_processing_time),
    ])

    wait_until_done(port)
    new_block_from_redis()
  end

  def process(
    transactions,
    env \\ %{
      block_number: 1,
      block_winner: Config.public_key(),
      block_hash: <<>>,
    }
  ) do
    redis_connection_url = Application.fetch_env!(:node, :redis_url)
    encoded_transactions = Enum.map(transactions, fn transaction ->
      transaction
        |> Transaction.with_code()
        |> Cbor.encode()
    end)
    Redis.push("block", encoded_transactions)
    port = run([
      redis_connection_url,
      "process_existing_block",
      Cbor.encode(env) |> Base.encode16
    ])

    wait_until_done(port)
    {:ok, changeset} = Redis.fetch("changeset", <<>>)
    Redis.delete("changeset")

    %{
      changeset_hash: Crypto.hash(changeset),
      transactions: done_transactions(),
    }
  end

  def wait_until_done(port) do
    receive do
      :cancel ->
        Port.close(port)
        :cancelled
      {_port, {:data, '\n'}} -> nil
      {_port, {:data, message}} ->
        IO.write message
        wait_until_done(port)
    end
  end

  def new_block_from_redis() do
    {:ok, changeset} = Redis.fetch("changeset", <<>>)
    Redis.delete("changeset")
    Block.next_block_params()
    |> Map.merge(%{
      changeset_hash: Crypto.hash(changeset),
      transactions: done_transactions(),
    })
  end

  def done_transactions do
    {:ok, transactions} = Redis.get_list("transactions::done")
    {:ok, results} = Redis.get_list("results")
    Redis.delete("transactions::done")
    Redis.delete("results")

    Enum.zip(transactions, results)
      |> Enum.map(fn {transaction_bytes, result_bytes} ->
        <<return_code::little-integer-size(32), return_value::binary>> = result_bytes
        transaction = Cbor.decode!(transaction_bytes)
        Cbor.decode!(transaction_bytes)
          |> Map.merge(%{
            hash: <<0::256>>,
            block_hash: nil,
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
