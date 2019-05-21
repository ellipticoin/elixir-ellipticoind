defmodule Router do
  require Logger
  use Plug.Router
  alias Ellipticoind.Memory

  if Mix.env() == :dev do
    use Plug.Debugger, otp_app: :ellipticoind
  end

  alias Ellipticoind.Plug.CBOR
  alias Ellipticoind.Repo
  alias Ellipticoind.Models.{Block, Transaction}

  plug(CORSPlug)

  plug(Plug.Parsers,
    parsers: [CBOR],
    body_reader: {CacheBodyReader, :read_body, []},
    cbor_decoder: Cbor
  )

  use Plug.ErrorHandler

  plug(:match)
  plug(:dispatch)

  get "/transactions/:block_hash/:transaction_index" do
    block =
      Block
      |> Repo.get_by(hash: Base.url_decode64!(conn.path_params["block_hash"]))
      |> Repo.preload(:transactions)


    if block do
      IO.inspect block.transactions
             # |> Enum.at(String.to_integer(conn.path_params["transaction_index"]))
      resp = block.transactions
             |> Enum.at(String.to_integer(conn.path_params["transaction_index"]))
             |> Transaction.as_binary()
      send_resp(conn, 200, resp)
    else
      send_resp(conn, 404, "not found")
    end
  end

  get "/blocks/:hash" do
    resp =
      Block
      |> Repo.get_by(hash: Base.url_decode64!(conn.path_params["hash"]))
      |> Repo.preload(:transactions)
      |> Block.as_binary()

    send_resp(conn, 200, resp)
  end

  get "/memory/:key" do
    key = Base.url_decode64!(conn.path_params["key"])
    resp = Memory.get(key) || <<>>
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
