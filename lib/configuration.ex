defmodule Configuration do
  def hashfactor_target(),
    do: Application.fetch_env!(:ellipticoind, :hashfactor_target)

  def private_key(),
    do:
      Application.fetch_env!(:ellipticoind, :private_key)
      |> Base.decode64!()

  def transaction_processing_time(),
    do: Application.fetch_env!(:ellipticoind, :transaction_processing_time)

  def redis_url(), do: Application.fetch_env!(:ellipticoind, :redis_url)
  def rocksdb_path(), do: Application.fetch_env!(:ellipticoind, :rocksdb_path)

  def public_key(),
    do:
      private_key()
      |> Crypto.private_key_to_public_key()

  def p2p_transport() do
    transport = Application.fetch_env!(:ellipticoind, :p2p_transport)
    options = Application.fetch_env!(:ellipticoind, transport)

    {transport, Enum.into(options, %{})}
  end

  def cowboy() do
    {Plug.Cowboy,
     scheme: :http,
     plug: Router,
     options: [
       dispatch: Cowboy.dispatch(),
       port: Application.fetch_env!(:ellipticoind, :port)
     ]}
  end
end
