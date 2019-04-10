defmodule Router do
  require Logger
  use Plug.Router

  if Mix.env() == :dev do
    use Plug.Debugger, otp_app: :node
  end

  alias Node.Plug.CBOR
  alias Node.Repo
  alias HTTP.SignatureAuth
  alias Node.Models.{Block, Contract, Transaction}

  plug(CORSPlug)

  plug(Plug.Parsers,
    parsers: [CBOR],
    body_reader: {CacheBodyReader, :read_body, []},
    cbor_decoder: Cbor
  )

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

  get "/blocks" do
    limit =
      if conn.query_params["limit"] do
        Integer.parse(conn.query_params["limit"])
        |> elem(0)
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

  def parse_get_request(conn) do
    arguments = Cbor.decode!(Base.decode16!(conn.query_params["arguments"]))
    address = Base.decode16!(conn.path_params["address"], case: :lower)

    %{
      address: address,
      function: String.to_atom(conn.query_params["function"]),
      arguments: arguments,
      contract_name: String.to_atom(conn.path_params["contract_name"])
    }
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
    send_resp(conn, conn.status, "")
  end
end
