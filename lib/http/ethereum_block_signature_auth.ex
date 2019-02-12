defmodule HTTP.EthereumBlockSignatureAuth do
  defmodule UnauthorizedError do
    @moduledoc """
    Error raised when a signature is invalid
    """

    defexception message: "Invaild Signature", plug_status: 401
  end

  def verify_signature(conn, address) do
    signature = get_signature(conn)
    body = Enum.fetch!(conn.assigns.raw_body, 0)
    message = <<conn.params.number::size(64)>> <> Crypto.hash(body)

    if Ethereum.Helpers.valid_signature?(signature, message, address) do
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
