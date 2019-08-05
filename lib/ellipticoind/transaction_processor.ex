defmodule Ellipticoind.TransactionProcessor do
  @crate "transaction_processor"
  import NativeModule
  alias Ellipticoind.Models.{Block, Transaction}
  alias Ellipticoind.{Memory, Storage}

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

    port =
      call_native(
        [
          "process_existing_block",
          Configuration.redis_url(),
          Configuration.rocksdb_path(),
          env |> Cbor.encode() |> Base.encode64()
        ],
        Enum.map(block.transactions, &Transaction.as_map/1)
      )

    case receive_native(port) do
      :stop ->
        Port.close(port)
        :stop

      [transactions, memory_changeset, storage_changeset] ->
        Memory.write_changeset(memory_changeset, env.block_number)
        Storage.write_changeset(storage_changeset, env.block_number)

        %{
          changeset_hash: Crypto.hash(<<>>),
          transactions: transactions
        }
    end
  end

  def process_new_block() do
    env = %{
      block_number: Block.next_block_number(),
      block_winner: Configuration.public_key(),
      block_hash: <<>>
    }

    port =
      call_native([
        "process_new_block",
        Configuration.redis_url(),
        Configuration.rocksdb_path(),
        env |> Cbor.encode() |> Base.encode64(),
        Configuration.transaction_processing_time() |> Integer.to_string()
      ])

    case receive_native(port) do
      :stop ->
        Port.close(port)
        :stopped

      [transactions, memory_changeset, storage_changeset] ->
        Memory.write_changeset(memory_changeset, env.block_number)
        Storage.write_changeset(storage_changeset, env.block_number)

        Block.next_block_params()
        |> Map.merge(%{
          changeset_hash: Crypto.hash(<<>>),
          transactions: transactions
        })
    end
  end

  def receive_native(port) do
    case receive_stop_or_message(port) do
      :stop ->
        :stop

      message ->
        case List.to_string(message) do
          "debug: " <> message ->
            IO.write(message)
            receive_native(port)

          message ->
            message
            |> String.trim("\n")
            |> String.split(" ")
            |> Enum.map(fn item ->
              item
              |> Base.decode64!()
              |> Cbor.decode!()
            end)
        end
    end
  end

  def receive_stop_or_message(_port, message \\ '') do
    receive do
      :stop ->
        :stop

      {port, {:data, message_part}} ->
        if <<List.last(message_part)>> == "\n" do
          Enum.concat(message, message_part)
        else
          receive_stop_or_message(port, Enum.concat(message, message_part))
        end
    end
  end

  def call_native(args \\ [], payload \\ nil) do
    port =
      Port.open({:spawn_executable, path_to_executable()},
        args: args
      )

    if payload do
      send(port, {self(), {:command, Base.encode64(Cbor.encode(payload)) <> "\n"}})
    end

    port
  end

  def path_to_executable(), do: Application.app_dir(:ellipticoind, ["priv", "native", @crate])
end
