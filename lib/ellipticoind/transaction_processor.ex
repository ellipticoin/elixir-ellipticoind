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

    call_native([
      "process_existing_block",
      Config.redis_url(),
      Config.rocksdb_path(),
      env |> Cbor.encode() |> Base.encode64(),
    ],
      Enum.map(block.transactions, &Transaction.as_map/1)
    )

    case receive_native() do
      :cancelled ->
        :cancelled
      [transactions, memory_changeset, storage_changeset] ->
        Memory.write_changeset(memory_changeset, env.block_number)
        Storage.write_changeset(storage_changeset, env.block_number)
        %{
          changeset_hash: <<>>,
          transactions: transactions
        }
    end
  end

  def process_new_block() do
    env = %{
      block_number: Block.next_block_number(),
      block_winner: Config.public_key(),
      block_hash: <<>>
    }

    call_native([
      "process_new_block",
      Config.redis_url(),
      Config.rocksdb_path(),
      env |> Cbor.encode() |> Base.encode64(),
      Config.transaction_processing_time() |> Integer.to_string(),
    ])

    case receive_native() do
      :cancelled ->
        :cancelled
      [transactions, memory_changeset, storage_changeset] ->
        Memory.write_changeset(memory_changeset, env.block_number)
        Storage.write_changeset(storage_changeset, env.block_number)
        Block.next_block_params()
          |> Map.merge(%{
            changeset_hash: <<>>,
            transactions: transactions
          })

    end
  end


  def receive_native() do
    case receive_cancel_or_message() do
      :cancelled ->
        :cancelled

      message ->
        case List.to_string(message) do
          "debug: " <> message ->
            IO.write message
            receive_native()
          message -> message
            |> String.trim("\n")
            |> String.split(" ")
            |> Enum.map(fn(item) ->
              item
                |> Base.decode64!()
                |> Cbor.decode!()
            end)
        end
    end
  end

  def receive_cancel_or_message(message \\ '') do
    receive do
      :cancel ->
        :cancelled

      {_port, {:data, message_part}} ->
        if length(message_part) > 65535 do
          receive_cancel_or_message(Enum.concat(message, message_part))
        else
          Enum.concat(message, message_part)
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
  end

  def path_to_executable(), do: Application.app_dir(:ellipticoind, ["priv", "native", @crate])
end
