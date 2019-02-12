defmodule TransactionProcessor do
  use GenServer
  alias Redis.PubSub

  @crate "transaction_processor"
  @channel "transaction_processor"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    redis_connection_url = Application.fetch_env!(:blacksmith, :redis_url)
    postgres_connection_url = postgres_connection_url()
    {:ok, redis} = Redix.start_link(redis_connection_url)

    Port.open({:spawn_executable, path_to_executable()},
      args: [redis_connection_url, postgres_connection_url]
    )

    {:ok,
     Map.merge(state, %{
       redis => redis
     })}
  end

  defp postgres_connection_url() do
    repo = Application.fetch_env!(:blacksmith, Blacksmith.Repo)
    username = Keyword.fetch!(repo, :username)
    hostname = Keyword.fetch!(repo, :hostname)
    port = if Keyword.fetch(repo, :port) == :error, do: "", else: ":#{Keyword.fetch(repo, :port)}"
    database = Keyword.fetch!(repo, :database)

    "postgres://#{username}:#{hostname}@#{hostname}:#{port}/#{database}"
  end

  def proccess_transactions(duration) do
    GenServer.cast(__MODULE__, {:proccess_transactions, duration})
    PubSub.receive_message(@channel, "done")
  end

  def proccess_block(transactions) do
    encoded_transactions = Enum.map(transactions, &Cbor.encode/1)
    Redis.push("block", encoded_transactions)
    Redis.publish(@channel, ["proccess_block"])
    PubSub.receive_message(@channel, "done")
  end

  def handle_cast({:proccess_transactions, duration}, state) do
    Redis.publish(@channel, ["proccess_transactions", duration])
    {:noreply, state}
  end

  def handle_info({:pubsub, _channel, _message}, state) do
    {:noreply, state}
  end

  def handle_info({_port, {:data, message}}, state) do
    IO.write(message)
    {:noreply, state}
  end

  def path_to_executable(), do: Application.app_dir(:blacksmith, ["priv", "native", @crate])

  def mode() do
    if(Mix.env() == :prod, do: :release, else: :debug)
  end
end
