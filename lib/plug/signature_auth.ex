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
      signature_hex
    ] = String.split(authorization, " ")

    public_key = conn.params.sender
    signature = Base.decode16!(signature_hex, case: :lower)

    body = Enum.fetch!(conn.assigns.raw_body, 0)
    _path = conn.request_path

    conn =
      Map.put(
        conn,
        :assigns,
        conn.assigns
        |> Map.put(:body, body)
        |> Map.put(:public_key, public_key)
      )

    if !Crypto.valid_signature?(
         signature,
         body,
         public_key
       ) do
      throw(UnauthorizedError)
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
