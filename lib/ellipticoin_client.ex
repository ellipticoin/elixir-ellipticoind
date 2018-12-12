defmodule EllipticoinClient do
  defstruct peer: nil
  use HTTPoison.Base

  def process_response_body(body) do
    body
      |> Cbor.decode!
  end

  def new(peer) do
    struct(__MODULE__, %{peer: peer})
  end

  def get_peers(self) do
    get(Map.fetch!(self, :peer) <> "/peers", [], hackney: [:insecure])
  end

  def connect(self, my_address) do
    IO.puts "Posting to: #{Map.fetch!(self, :peer) <> "/peers"}"
    post(
      Map.fetch!(self, :peer) <> "/peers",
      Cbor.encode(%{url: my_address}),
      [{"Content-Type", "application/cbor"}],
      hackney: [:insecure],
    )
  end
end
