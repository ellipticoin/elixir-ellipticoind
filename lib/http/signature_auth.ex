defmodule HTTP.SignatureAuth do
  alias Crypto.Ed25519

  defmodule UnauthorizedError do
    @moduledoc """
    Error raised when a signature is invalid
    """

    defexception message: "Invaild Signature", plug_status: 401
  end

  def verify_block_signature(conn, address) do
    signature = get_signature(conn)
    body = Enum.fetch!(conn.assigns.raw_body, 0)
    message = <<conn.params.number::size(64)>> <> Crypto.hash(body)

    if Ethereum.Helpers.valid_signature?(signature, message, address) do
      conn
    else
      throw(UnauthorizedError)
    end
  end

  def verify_signature(conn) do
    public_key = conn.params.sender
    signature = get_signature(conn)
    body = Enum.fetch!(conn.assigns.raw_body, 0)

    if Ed25519.valid_signature?(signature, body, public_key) do
      conn
    else
      throw(UnauthorizedError)
    end
  end

  def get_signature(conn) do
    [authorization] = Plug.Conn.get_req_header(conn, "authorization")

    [
      "Signature",
      signature_hex
    ] = String.split(authorization, " ")

    Base.decode16!(signature_hex, case: :lower)
  end
end
