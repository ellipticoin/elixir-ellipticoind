defmodule Router do
  import Ecto.Query
  require Logger
  use Plug.Router
  alias Ellipticoind.Memory

  if Mix.env() == :dev do
    use Plug.Debugger, otp_app: :ellipticoind
  end

  alias Ellipticoind.Plug.CBOR
  alias Ellipticoind.Repo
  alias Ellipticoind.Models.{Block, Transaction}
  alias Ellipticoind.Views.{BlockView, TransactionView}

  plug(CORSPlug)

  plug(Plug.Parsers,
    parsers: [CBOR],
    body_reader: {CacheBodyReader, :read_body, []},
    cbor_decoder: Cbor
  )

  use Plug.ErrorHandler

  plug(:match)
  plug(:dispatch)

  get "/transactions/:transaction_hash" do
    transaction_hash = Base.url_decode64!(conn.path_params["transaction_hash"])

    transaction =
      Repo.one(
        from(t in Transaction,
          where: t.hash == ^transaction_hash,
          order_by: [desc: t.id],
          limit: 1
        )
      )

    if transaction do
      resp =
        TransactionView.as_map(transaction)
        |> Cbor.encode()

      send_resp(conn, 200, resp)
    else
      send_resp(conn, 404, "not found")
    end
  end

  get "/blocks/:hash" do
    Block
    |> Repo.get_by(hash: Base.url_decode64!(conn.path_params["hash"]))
    |> Repo.preload(:transactions)
    |> BlockView.as_map()
    |> render_success(conn)
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
      |> Enum.map(&BlockView.as_map/1)

    send_resp(conn, 200, Cbor.encode(%{blocks: blocks}))
  end

  post "/transactions" do
    case Transaction.from_signed_transaction(conn.params) do
      {:ok, transaction} ->
        P2P.broadcast(transaction)
        Transaction.post(transaction)

        transaction_hash =
          TransactionView.as_map(transaction)
          |> Map.delete(:hash)
          |> Transaction.hash()

        render_success(conn, transaction_hash)

      {:error, :invalid_signature} ->
        render_error(conn, 401, "invalid_signature")

      {:error, reason} ->
        render_error(conn, 500, Atom.to_string(reason))
    end
  end

  def render_success(conn, response) do
    send_resp(conn, 200, Cbor.encode(response))
  end

  def render_error(conn, error_code, error_text) do
    send_resp(conn, error_code, error_text)
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
    send_resp(conn, conn.status, "")
  end
end
