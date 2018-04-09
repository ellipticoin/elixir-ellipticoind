defmodule Router do
  alias Blacksmith.Plug.SignatureAuth
  use Plug.Router
  plug(SignatureAuth, only_methods: ["POST", "PUT"])
  use Plug.ErrorHandler

  plug :match
  plug :dispatch

  put "/:nonce/:address/:contract_name" do
    deploy(parse_request(conn))
    send_resp(conn, 200, "")
  end

  post "/:nonce/:address/:contract_name" do
    case run(parse_request(conn)) do
      {:ok, response } -> send_resp(conn, 200, response)
      {:err, response } -> send_resp(conn, 500, response)
    end
  end

  def parse_request(conn) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)

    Map.merge(
      conn.path_params,
      %{
        "body" => body,
        "public_key" => Enum.fetch!(Plug.Conn.get_req_header(conn, "public_key"), 0),
      }
    )

  end
  def run(%{
    "address" => address,
    "contract_name" => contract_name,
    "nonce" => nonce,
    "body" => body,
    "public_key" => public_key,
  }) do
      case GenServer.call(VM, {:call, %{
        address: Base.decode16!(address, case: :lower),
        contract_name: contract_name,
        sender: public_key,
        rpc: body,
        nonce: Base.decode16!(nonce, case: :lower),
      }}) do
        {:error, _code, message} -> {:error, 500, message}
        response -> response
      end
  end

  def deploy(%{
    "address" => address,
    "contract_name" => contract_name,
    "nonce" => _nonce,
    "body" => body,
    "public_key" => public_key,
  }) do
      GenServer.call(VM, {:deploy, %{
        sender: public_key,
        address: address,
        contract_name: contract_name,
        code: body,
      }})
  end

  def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
    send_resp(conn, conn.status, "")
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
