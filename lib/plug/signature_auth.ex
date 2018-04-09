defmodule Blacksmith.Plug.SignatureAuth do
  defmodule UnauthorizedError do
    @moduledoc """
    Error raised when a signature is invalid
    """

    defexception message: "Invaild Signature", plug_status: 401
  end

  def init(options), do: options

  def call(conn, options) do
    if auth_required?(conn, options) do
      verify_signature(conn)
    else
      conn
    end
  end

  def verify_signature(conn) do
    [authorization] = Plug.Conn.get_req_header(conn, "authorization")

    [
      "Signature",
      public_key_hex,
      signature_hex,
      nonce_hex
    ] = String.split(authorization, " ")

    public_key = Base.decode16!(public_key_hex, case: :lower)
    signature = Base.decode16!(signature_hex, case: :lower)
    nonce = Base.decode16!(nonce_hex, case: :lower)

    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    "/" <> path = conn.request_path

    conn = conn
      |> Plug.Conn.put_req_header("public_key", public_key)
      |> Plug.Conn.put_req_header("nonce", nonce)

    if !Crypto.valid_signature?(signature, path <> body, public_key)
    do
      throw UnauthorizedError
    end

    conn
  end

  def auth_required?(conn, options) do
    if options[:only_methods] do
      Enum.member?(options[:only_methods], conn.method)
    else
      true
    end
  end
end
