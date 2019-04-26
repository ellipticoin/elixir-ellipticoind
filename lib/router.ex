defmodule Router do
  import Utils
  require Logger
  use Plug.Router

  if Mix.env() == :dev do
    use Plug.Debugger, otp_app: :node
  end

  alias Node.Plug.CBOR
  alias Node.Repo
  alias HTTP.SignatureAuth
  alias Node.Models.{Block, Transaction}

  plug(CORSPlug)

  plug(Plug.Parsers,
    parsers: [CBOR],
    body_reader: {CacheBodyReader, :read_body, []},
    cbor_decoder: Cbor
  )

  use Plug.ErrorHandler

  plug(:match)
  plug(:dispatch)

  get "/transactions/:hash" do
    resp =
      Transaction
      |> Repo.get_by(hash: Base.url_decode64!(conn.path_params["hash"]))
      |> Transaction.as_binary()

    send_resp(conn, 200, resp)
  end

  get "/blocks/:hash" do
    resp =
      Block
      |> Repo.get_by(hash: Base.url_decode64!(conn.path_params["hash"]))
      |> Repo.preload(:transactions)
      |> Block.as_binary()

    send_resp(conn, 200, resp)
  end

  get "/memory/:address/:contract/:key" do
    address = Base.url_decode64!(conn.path_params["address"])
    contract = Base.url_decode64!(conn.path_params["contract"])
    key = Base.url_decode64!(conn.path_params["key"])
    resp = Redis.get_binary(address <> contract <> key) |> ok || <<>>
    send_resp(conn, 200, resp)
  end

  get "/blocks" do
    limit =
      if conn.query_params["limit"] do
        String.to_integer(conn.query_params["limit"])
      else
        nil
      end

    blocks =
      Block.latest(limit)
      |> Repo.all()
      |> Repo.preload(:transactions)
      |> Enum.map(&Block.as_map/1)

    send_resp(conn, 200, Cbor.encode(%{blocks: blocks}))
  end

  post "/transactions" do
    SignatureAuth.verify_signature(conn)

    Transaction.post(conn.params)

    send_resp(conn, 200, Cbor.encode(""))
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
    send_resp(conn, conn.status, "")
  end
end
