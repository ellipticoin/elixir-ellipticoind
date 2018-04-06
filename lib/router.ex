defmodule Router do
  use Plug.Router

  plug :match
  plug :dispatch

  put "/:nonce/:address/:contract_name" do
    params = parse_request(conn)
    deploy(params)
    send_resp(conn, 200, "")
  end

  post "/:nonce/:address/:contract_name" do
    params = parse_request(conn)
    case run(parse_request(conn)) do
      {:ok, response } -> send_resp(conn, 200, response)
      {:err, response } -> send_resp(conn, 500, response)
    end
  end

  def parse_request(conn) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)

    [authorization] = get_req_header(conn, "authorization")
    ["Signature", public_key, signature] = String.split(authorization, " ")

    Map.merge(
      conn.path_params,
      %{
        "body" => body,
        "signature" => %{
          "public_key" => Base.decode16!(public_key, case: :lower),
          "signature" => Base.decode16!(signature, case: :lower),
        }
      }
    )

  end
  def run(%{
    "address" => address,
    "contract_name" => contract_name,
    "nonce" => nonce,
    "body" => body,
    "signature" => signature,
  }) do
      case GenServer.call(VM, {:call, %{
        address: Base.decode16!(address, case: :lower),
        contract_name: contract_name,
        sender: signature["public_key"],
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
    "nonce" => nonce,
    "body" => body,
    "signature" => signature,
  }) do
      GenServer.call(VM, {:deploy, %{
        sender: signature["public_key"],
        address: address,
        contract_name: contract_name,
        code: body,
      }})
  end

  def sender(request) do
    <<
    "Signature ",
    sender::binary-size(64),
      " ",
    _signature::binary-size(128)
    >> = :cowboy_req.header("authorization", request)

    sender
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
