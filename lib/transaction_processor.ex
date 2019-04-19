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
    best_block = Block.best() |> Repo.one()

    env = %{
      block_number: if(best_block, do: best_block.number + 1, else: 0),
      block_winner: Config.public_key(),
      block_hash: <<>>
    }

    port =
      run([
        Config.redis_url(),
        "process_new_block",
        Cbor.encode(env) |> Base.encode16(),
        Integer.to_string(Config.transaction_processing_time())
      ])

    wait_until_done(port)

    Block.next_block_params()
    |> Map.merge(%{
      changeset_hash: changeset_hash(),
      transactions: done_transactions()
    })
  end

  def process(block, env \\ %{}) do
    env =
      Map.merge(
        %{
          block_number: 1,
          block_winner: Config.public_key(),
          block_hash: <<>>
        },
        env
      )

    encoded_transactions =
      Enum.map(block.transactions, fn transaction ->
        transaction
        |> Transaction.with_code()
        |> Cbor.encode()
      end)

    Redis.push("block", encoded_transactions)

    port =
      run([
        Config.redis_url(),
        "process_existing_block",
        Cbor.encode(env) |> Base.encode16()
      ])

    wait_until_done(port)
    transactions = done_transactions()
    changeset_hash = changeset_hash()
    errors = transaction_errors(block, transactions, changeset_hash)

    if !Enum.empty?(errors) do
      {:error, errors}
    else
      {:ok,
       %{
         changeset_hash: changeset_hash,
         transactions: transactions
       }}
    end
  end

  def changeset_hash() do
    {:ok, changeset} = Redis.fetch("changeset", <<>>)
    Redis.delete("changeset")
    Crypto.hash(changeset)
  end

  def transaction_errors(block, transactions, changeset_hash) do
    Enum.concat([
      changeset_errors(block, changeset_hash),
      return_code_errors(block, transactions),
      return_value_errors(block, transactions)
    ])
  end

  def changeset_errors(block, changeset_hash) do
    if block.changeset_hash != changeset_hash do
      [{:changeset_hash_mismatch, changeset_hash, block.changeset_hash}]
    else
      []
    end
  end

  def return_value_errors(block, transactions) do
    Enum.zip(block.transactions, transactions)
    |> Enum.reduce([], fn {proposed_transaction, transaction}, errors ->
      if proposed_transaction.return_value != transaction.return_value do
        [
          {
            :return_value_mismatch,
            transaction.return_value,
            proposed_transaction.return_value
          }
          | errors
        ]
      else
        errors
      end
    end)
  end

  def return_code_errors(block, transactions) do
    Enum.zip(block.transactions, transactions)
    |> Enum.reduce([], fn {proposed_transaction, transaction}, errors ->
      if proposed_transaction.return_code != transaction.return_code do
        [
          {
            :return_code_mismatch,
            transaction.return_code,
            proposed_transaction.return_code
          }
          | errors
        ]
      else
        errors
      end
    end)
  end

  def wait_until_done(port) do
    receive do
      :cancel ->
        Port.close(port)
        :cancelled

      {_port, {:data, '\n'}} ->
        nil

      {_port, {:data, message}} ->
        IO.write(message)
        wait_until_done(port)
    end
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
        return_code: return_code,
        return_value: Cbor.decode!(return_value)
      })
      |> Map.delete(:code)
    end)
  end

  def handle_info({_port, {:data, message}}, state) do
    IO.write(message)
    {:noreply, state}
  end

  defp run(args) do
    Port.open({:spawn_executable, path_to_executable()}, args: args)
  end

  def path_to_executable(), do: Application.app_dir(:node, ["priv", "native", @crate])
end
