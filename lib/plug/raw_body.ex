defmodule Blacksmith.Plug.RawBody do
  def init(options), do: options

  def call(conn, _options) do
    {:ok, body, _} = Plug.Conn.read_body(conn)

    conn
    |> Plug.Conn.put_private(:raw_body, body)
    |> Plug.Conn.delete_req_header("content-type")
  end
end
