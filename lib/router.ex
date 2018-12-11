defmodule Router do
  use Plug.Router

  if Mix.env() == :dev do
    use Plug.Debugger, otp_app: :blacksmith
  end

  alias Blacksmith.Plug.CBOR
  alias HTTP.SignatureAuth
  alias Models.Contract
  alias Ethereum.Contracts.EllipticoinStakingContract

  plug(CORSPlug)

  plug(Plug.Parsers,
    parsers: [CBOR],
    body_reader: {CacheBodyReader, :read_body, []},
    cbor_decoder: Cbor
  )

  # plug(
  #   SignatureAuth,
  #   only_methods: ["POST", "PUT"]
  # )
  #
  use Plug.ErrorHandler

  plug(:match)
  plug(:dispatch)

  get "/:address/:contract_name" do
    result =
      conn
      |> parse_get_request()

    {:ok, result} = Contract.get(result)

    send_resp(conn, 200, result)
  end

  post "/nodes" do
    P2P.add_peer(conn.params.url)

    send_resp(conn, 200, "")
  end

  post "/blocks" do
    {:ok, winner} = EllipticoinStakingContract.winner()
    SignatureAuth.verify_block_signature(conn, winner)

    # Block.apply(conn.params)
    send_resp(conn, 200, "")
  end

  get "/blocks" do
    _limit =
      if conn.query_params["limit"] do
        Integer.parse(conn.query_params["limit"])
      else
        nil
      end

    send_resp(conn, 200, Cbor.encode(%{blocks: []}))
  end

  post "/transactions" do
    SignatureAuth.verify_signature(conn)

    Contract.post(conn.params)

    send_resp(conn, 200, "")
  end

  def parse_get_request(conn) do
    params = Cbor.decode!(Base.decode16!(conn.query_params["params"]))
    address = Base.decode16!(conn.path_params["address"], case: :lower)

    %{
      address: address,
      method: String.to_atom(conn.query_params["method"]),
      params: params,
      contract_name: conn.path_params["contract_name"]
    }
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
    send_resp(conn, conn.status, "")
  end
end
