defmodule RequestHandler do
  def init(request, options) do
    reply = if authorized?(request) do
        case :cowboy_req.method(request) do
        "POST" ->
          case run(request) do
            {:ok, result} ->
              success_response(result, request)
            {:error, code, message} ->
              error_response(code, message, request)
          end

        "PUT" ->
          reply = deploy(request)
          {:ok, reply, options}
        _ ->
          {:error, 501, "Not Implemented"}
        end
      else
        {:error, 401, "Invalid signature"}
      end

    {:ok, reply, options}
  end

  def authorized?(request) do
    method = :cowboy_req.method(request)
    message = Base.decode16!(:cowboy_req.qs(request), case: :lower)

    "/" <> path = :cowboy_req.path(request)

    if method == "POST" do
      case :cowboy_req.header("authorization", request) do
        <<
          "Signature ",
          sender::binary-size(32),
          " ",
          signature::binary-size(64)
        >> ->
          Crypto.valid_signature?(signature, path <> message, sender)
        _ ->
          false
      end
    else
      true
    end
  end

  def deploy(request) do
      %{
        contract_name: contract_name,
        nonce: _nonce,
      } = :cowboy_req.bindings(request)

      code = Base.decode16!(:cowboy_req.qs(request), case: :lower)
      GenServer.call(VM, {:deploy, %{
        sender: sender(request),
        address: sender(request),
        contract_name: contract_name,
        code: code,
      }})
  end

  def read_body(request) do
    {:ok, body, _headers} = :cowboy_req.read_body(request)
    body
  end

  def success_response(payload, request) do
    :cowboy_req.reply(
      200,
      %{"Content-Type" => "application/cbor"},
      payload,
      request
    )
  end

  def error_response(code, message, request) do
    :cowboy_req.reply(
      code,
      %{"Content-Type" => "text/plain"},
      message,
      request
    )
  end

  def run(request) do
        %{
          address: address,
          contract_name: contract_name,
          nonce: nonce,
        } = :cowboy_req.bindings(request)
          rpc = :cowboy_req.qs(request)
            |> Base.decode16!(case: :lower)

      case GenServer.call(VM, {:call, %{
        address: Base.decode16!(address, case: :lower),
        contract_name: contract_name,
        sender: sender(request),
        rpc: rpc,
        nonce: Base.decode16!(nonce, case: :lower),
      }}) do
        {:error, _code, message} -> {:error, 500, message}
        response -> response
      end
  end

  def sender(request) do
    <<
    "Signature ",
    sender::binary-size(32),
      " ",
    _signature::binary-size(64)
    >> = :cowboy_req.header("authorization", request)

    sender
  end
end
