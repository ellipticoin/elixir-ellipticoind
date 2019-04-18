defmodule TransactionProcessor do
  alias Node.Repo
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
    best_block = Block.best() |> Repo.one()
    env = %{
      block_number: (if best_block, do: best_block.number + 1, else: 0),
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

  def process(proposed_transactions, env \\ %{}) do
    env = Map.merge(%{
      block_number: 1,
      block_winner: Config.public_key(),
      block_hash: <<>>,
    }, env)
    redis_connection_url = Application.fetch_env!(:node, :redis_url)
    encoded_transactions = Enum.map(proposed_transactions, fn transaction ->
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

    transactions = done_transactions()
    errors = transaction_errors(proposed_transactions, transactions)

    if !Enum.empty?(errors) do
      {:error, errors}
    else
        {:ok, %{
            changeset_hash: Crypto.hash(changeset),
            transactions: transactions,
        }}
    end
  end

  def transaction_errors(proposed_transactions, transactions) do
    Enum.zip(proposed_transactions, transactions)
    |> Enum.reduce([], fn ({proposed_transaction, transaction}, errors) ->
      errors =
        if proposed_transaction.return_value != transaction.return_value do
          [{
            :return_value_mismatch,
            transaction.return_value,
            proposed_transaction.return_value,
          } | errors]
        else
         errors
        end

      errors =
        if proposed_transaction.return_code != transaction.return_code do
          [{
            :return_code_mismatch,
            transaction.return_code,
            proposed_transaction.return_code,
          } | errors]
        else
         errors
        end


    end
    )
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
