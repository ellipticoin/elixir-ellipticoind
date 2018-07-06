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


  get "/:address/:contract_name/:method" do
    conn
      |> parse_get_request()
      |> add_to_pool()
      |> send_resp(conn)
  end

  put "/:address/:contract_name" do
    conn
      |> deploy()

    send_resp(conn, 200, "")
  end


  post "/transactions" do
    add_to_pool(conn.assigns.body)

    send_resp(conn, 200, "")
  end

  def send_resp(resp, conn) do
    case resp do
      {:ok, response } -> send_resp(conn, 200, "")
      {:error, error_code, response } -> send_resp(conn, 500, response)
    end
  end

  def parse_get_request(conn) do
    {:ok, rpc} = Cbor.decode(Base.decode16!(conn.query_string, case: :lower))
    Map.merge(
      conn.path_params
      |> Map.Helpers.atomize_keys,
      %{
        address: Base.decode16!(conn.path_params["address"], case: :lower),
        method: rpc[:method],
        params: rpc[:params],
        nonce: nil,
        sender: <<>>,
      }
    )
  end

  def add_to_pool(options) do
    GenServer.call(TransactionPool, {:add, options})
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
