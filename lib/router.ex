defmodule Router do
  use Plug.Router
  if Mix.env == :dev do
    use Plug.Debugger, otp_app: :blacksmith
  end

  alias Blacksmith.Plug.CBOR
  alias Blacksmith.Plug.SignatureAuth
  plug Plug.Parsers,
    parsers: [CBOR],
    body_reader: {CacheBodyReader, :read_body, []},
    cbor_decoder: Cbor
  plug(
    SignatureAuth,
    only_methods: ["POST", "PUT"],
  )
  use Plug.ErrorHandler

  plug :match
  plug :dispatch


  get "/:address/:contract_name" do
    conn
      |> parse_get_request()
      |> VM.run_get()
      |> send_resp(conn)
  end

  put "/contracts" do
    TransactionPool.add(conn.assigns.body)

    result = receive do
      {:transaction_forged, transaction} -> transaction
    end

    send_resp(conn, 200, result)
  end


  post "/transactions" do
    TransactionPool.add(conn.assigns.body)

    result = receive do
      {:transaction_forged, transaction} -> transaction
    end

    send_resp(conn, 200, result)
  end


  def send_resp(resp, conn) do
    case resp do
      {:ok, result } -> send_resp(conn, 200, result)
      {:error, error_code, response } -> send_resp(conn, 500, response)
    end
  end

  def parse_get_request(conn) do
    params = Cbor.decode!(Base.decode16!(conn.query_params["params"]))
    address = Base.decode16!(conn.path_params["address"], case: :lower)

    Map.merge(
      conn.path_params
      |> Map.Helpers.atomize_keys,
      %{
        address: address,
        method: String.to_atom(conn.query_params["method"]),
        params: params,
      }
    )
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
    send_resp(conn, conn.status, "")
  end
end
