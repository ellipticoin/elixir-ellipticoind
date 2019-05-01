defmodule Node.Models.Block.TransactionProcessor do
  alias Node.Repo
  alias Node.Models.{Block, Transaction}

  @crate "transaction_processor"

  def init(state), do: {:ok, state}

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

    case wait_until_done(port) do
      :cancelled ->
        :cancelled

      transactions ->
        Block.next_block_params()
        |> Map.merge(%{
          changeset_hash: changeset_hash(),
          transactions: transactions
        })
    end
  end

  def process(block, env \\ %{}) do
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

    port =
      run([
        Config.redis_url(),
        "process_existing_block",
        Cbor.encode(env) |> Base.encode16()
      ])

    case wait_until_done(port) do
      :cancelled ->
        :cancelled

      transactions ->
        changeset_hash = changeset_hash()

        %{
          changeset_hash: changeset_hash,
          transactions: transactions
        }
    end
  end

  def changeset_hash() do
    {:ok, changeset} = Redis.fetch("changeset", <<>>)
    Redis.delete("changeset")
    Crypto.hash(changeset)
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

  def handle_port_data("\n", _port), do: nil

  def handle_port_data(message, port) do
    IO.write(message)
    wait_until_done(port)
  end

  defp run(args) do
    Port.open({:spawn_executable, path_to_executable()}, args: args)
  end

  def path_to_executable(), do: Application.app_dir(:node, ["priv", "native", @crate])
end
