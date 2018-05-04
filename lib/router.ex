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
  plug(SignatureAuth, only_methods: ["POST", "PUT"])
  use Plug.ErrorHandler

  plug :match
  plug :dispatch

  get "/:address/:contract_name" do
    conn
      |> parse_get_request()
      |> run()
      |> send_resp(conn)
  end

  put "/:address/:contract_name" do
    conn
      |> parse_post_or_put_request()
      |> deploy()

    send_resp(conn, 200, "")
  end


  post "/:address/:contract_name" do
    conn
    |> parse_post_or_put_request()
    |> run()
    |> send_resp(conn)
  end

  def send_resp(resp, conn) do
    case resp do
      {:ok, response } -> send_resp(conn, 200, response)
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

  def parse_post_or_put_request(conn) do
    conn.params |>
      Map.Helpers.atomize_keys |>
      Map.merge(
        %{
          address: Base.decode16!(conn.path_params["address"], case: :mixed),
          sender: conn.assigns.public_key,
          nonce: conn.assigns.nonce,
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
