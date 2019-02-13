defmodule P2P do
  import Utils
  alias Blacksmith.Models.Block

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    peers = load_peers()
    connect_to_peers(peers)

    {:ok,
     Map.merge(state, %{
       peers: peers
     })}
  end

  def connect_to_peers(peers) do
    node_url = Application.fetch_env!(:blacksmith, :node_url)

    peers
    |> Enum.map(fn peer ->
      peer
      |> EllipticoinClient.new()
      |> EllipticoinClient.connect(node_url)
    end)
  end

  def load_peers() do
    bootnodes =
      File.read(bootnodes_path())
      |> ok
      |> String.split("\n")
      |> Enum.drop(-1)
      |> List.delete(Application.fetch_env!(:blacksmith, :node_url))

    if Application.fetch_env!(:blacksmith, :bootnode) do
      bootnodes
    else
      peer =
        bootnodes
        |> Enum.random()
        |> EllipticoinClient.new()

      EllipticoinClient.start()
      {:ok, %{body: peers}} = EllipticoinClient.get_peers(peer)
      peers
    end
  end

  defp bootnodes_path() do
    Application.app_dir(:blacksmith, ["priv", "bootnodes.txt"])
  end

  def add_peer(url) do
    GenServer.cast(__MODULE__, {:add_peer, url})
  end

  def peers() do
    GenServer.call(__MODULE__, {:peers})
  end

  def broadcast_block(block) do
    GenServer.cast(__MODULE__, {:broadcast_block, block})
  end

  def handle_cast({:add_peer, url}, state) do
    {:noreply, update_in(state[:peers], &[url | &1])}
  end

  def handle_cast(
        {:broadcast_block, block},
        state = %{
          peers: peers
        }
      ) do
    private_key = Application.fetch_env!(:blacksmith, :ethereum_private_key)

    Enum.each(peers, fn peer ->
      http_post_signed_block(peer, block, private_key)
    end)

    {:noreply, state}
  end

  def handle_call(
        {:peers},
        _from,
        state = %{
          peers: peers
        }
      ) do
    {:reply, peers, state}
  end

  defp http_post_signed_block(peer, block, private_key) do
    encoded_block = Block.as_cbor(block)
    message = <<block.number::size(64)>> <> Crypto.hash(encoded_block)
    {:ok, signature} = Ethereum.Helpers.sign(message, private_key)

    HTTPotion.post(
      peer <> "/blocks",
      [
        body: encoded_block,
        headers: headers(signature)
      ]
    )
  end

  defp headers(signature) do
    [
      "Content-Type": "application/cbor",
      Authorization: "Signature " <> Base.encode16(signature, case: :lower)
    ]
  end
end
