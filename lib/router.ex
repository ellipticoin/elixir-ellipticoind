defmodule Router do
  alias Blacksmith.Plug.RawBody
  alias Blacksmith.Plug.SignatureAuth
  use Plug.Router
  plug(RawBody)
  plug(SignatureAuth, only_methods: ["POST", "PUT"])
  use Plug.ErrorHandler

  plug :match
  plug :dispatch

  put "/:address/:contract_name" do
    conn
      |> parse_request()
      |> deploy()

    send_resp(conn, 200, "")
  end

  get "/:address/:contract_name" do
    conn
      |> parse_request()
      |> run()
      |> send_resp(conn)
  end

  post "/:address/:contract_name" do
    conn
      |> parse_request()
      |> run()
      |> send_resp(conn)
  end

  def send_resp(resp, conn) do
    case resp do
      {:ok, response } -> send_resp(conn, 200, response)
      {:error, error_code, response } -> send_resp(conn, 500, response)
    end

  end
  def parse_request(conn) do
    case conn.method do
      "GET" ->
        parse_get_request(conn)
      "POST" ->
        parse_post_request(conn)
      "PUT" ->
        parse_put_request(conn)
      _ -> throw Plug.BadRequestError
    end
  end

  def parse_get_request(conn) do
    Map.merge(
      conn.path_params,
      %{
        "address" => Base.decode16!(conn.path_params["address"], case: :lower),
        "rpc" => Base.decode16!(conn.query_string, case: :lower),
        "nonce" => nil,
        "sender" => <<>>,
      }
    )

  end

  def parse_post_request(conn) do
    Map.merge(
      conn.path_params,
      %{
        "address" => Base.decode16!(conn.path_params["address"], case: :mixed),
        "rpc" => conn.private[:raw_body],
        "sender" => Enum.fetch!(Plug.Conn.get_req_header(conn, "public_key"), 0),
        "nonce" => Enum.fetch!(Plug.Conn.get_req_header(conn, "nonce"), 0),
      }
    )
  end

  def parse_put_request(conn) do
    Map.merge(
      conn.path_params,
      %{
        "address" => Base.decode16!(conn.path_params["address"], case: :mixed),
        "code" => conn.private[:raw_body],
        "sender" => Enum.fetch!(Plug.Conn.get_req_header(conn, "public_key"), 0),
        "nonce" => Enum.fetch!(Plug.Conn.get_req_header(conn, "nonce"), 0),
      }
    )
  end

  def run(options) do
    GenServer.call(VM, {:call, options})
  end

  def deploy(options) do
    GenServer.call(VM, {:deploy, options})
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
    send_resp(conn, conn.status, "")
  end
end
