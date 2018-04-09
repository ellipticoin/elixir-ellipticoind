defmodule Router do
  alias Blacksmith.Plug.SignatureAuth
  use Plug.Router
  plug(SignatureAuth, only_methods: ["POST", "PUT"])
  use Plug.ErrorHandler

  plug :match
  plug :dispatch

  put "/:nonce/:address/:contract_name" do
    deploy(parse_post_request(conn))
    send_resp(conn, 200, "")
  end

  get "/:address/:contract_name" do
    case run(parse_request(conn)) do
      {:ok, response } -> send_resp(conn, 200, response)
      {:err, response } -> send_resp(conn, 500, response)
    end
  end

  post "/:nonce/:address/:contract_name" do
    case run(parse_request(conn)) do
      {:ok, response } -> send_resp(conn, 200, response)
      {:err, response } -> send_resp(conn, 500, response)
    end
  end

  def parse_request(conn) do
    case conn.method do
      "GET" ->
        parse_get_request(conn)
      "POST" ->
        parse_post_request(conn)
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
    {:ok, body, _conn} = Plug.Conn.read_body(conn)

    Map.merge(
      conn.path_params,
      %{
        "address" => Base.decode16!(conn.path_params["address"], case: :mixed),
        "rpc" => body,
        "sender" => Enum.fetch!(Plug.Conn.get_req_header(conn, "public_key"), 0),
      }
    )

  end

  def run(%{
    "address" => address,
    "contract_name" => contract_name,
    "nonce" => nonce,
    "rpc" => rpc,
    "sender" => sender,
  }) do
      case GenServer.call(VM, {:call, %{
        address: address,
        contract_name: contract_name,
        sender: sender,
        rpc: rpc,
        nonce: nonce,
      }}) do
        {:error, _code, message} -> {:error, 500, message}
        response -> response
      end
  end

  def deploy(%{
    "address" => address,
    "contract_name" => contract_name,
    "nonce" => _nonce,
    "rpc" => rpc,
    "sender" => sender,
  }) do
      GenServer.call(VM, {:deploy, %{
        sender: sender,
        address: address,
        contract_name: contract_name,
        code: rpc,
      }})
  end

  def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
    send_resp(conn, conn.status, "")
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
