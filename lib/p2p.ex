defmodule P2P do
  alias Models.Block

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do

    {:ok,
     Map.merge(state, %{
       peers: []
     })}
  end

  def add_peer(url) do
    GenServer.cast(__MODULE__, {:add_peer, url})
  end

  def broadcast_block(block) do
    GenServer.cast(__MODULE__, {:broadcast_block, block})
  end

  def handle_cast({:add_peer, url}, state) do
    {:noreply, update_in(state[:peers], &[url | &1])}
  end

  def handle_cast({:broadcast_block, block}, state =%{
    peers: peers,
  }) do
    private_key = Application.fetch_env!(:blacksmith, :ethereum_private_key)

    Enum.each(peers, fn peer ->
      http_post_signed_block(peer, block, private_key)
    end)

    {:noreply, state}
  end

  defp http_post_signed_block(peer, block, private_key) do
    encoded_block = Block.as_cbor(block)
    message = <<block.number::size(64)>> <> Crypto.hash(encoded_block)
    {:ok, signature} = Ethereum.Helpers.sign(message, private_key)

    HTTPoison.post(
      peer <> "blocks",
      encoded_block,
      headers(signature)
    )
  end

  defp headers(signature ) do
    %{
      "Content-Type": "application/cbor",
      Authorization: "Signature " <> Base.encode16(signature, case: :lower)
    }
  end
end
