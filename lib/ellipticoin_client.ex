defmodule EllipticoinClient do
  alias Ellipticoind.Models.Block
  use HTTPoison.Base

  def get_block(block_number) do
    cast_block(get!("blocks/#{block_number}").body)
  end

  def get_blocks() do
    get!("blocks",
         [],
         timeout: Configuration.client_timeout(),
         recv_timeout: Configuration.client_timeout()
    ).body
    |> Enum.map(&cast_block/1)
  end

  def process_request_url(url) do
    "#{random_peer()}/" <> url
  end

  def random_peer() do
    String.replace(Enum.random(P2P.get_peers()), "4461", "4460")
  end

  def process_response_body(body) do
    body
    |> Cbor.decode!
  end

  def cast_block(json) do
    fields = Block.__schema__(:fields) -- [:parent_hash]
    Ecto.Changeset.cast(%Block{}, json, fields)
    |> Ecto.Changeset.cast_assoc(:transactions)
    |> Ecto.Changeset.apply_changes()
  end
end
