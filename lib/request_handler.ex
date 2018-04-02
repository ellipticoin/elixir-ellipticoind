defmodule RequestHandler do
  def init(request, options) do
    method = :cowboy_req.method(request)
    body = read_body(request)


    reply = if authorized?(request, body) do
        case method do
        "POST" ->
          case run(request, body) do
            {:ok, result} ->
              success(result, request)
            {:error, code, message} ->
              error(code, message, request)
          end

        "PUT" ->
          reply = deploy(request, body)
          {:ok, reply, options}
        _ ->
          {:error, 501, "Not Implemented"}
        end
      else
        {:error, 401, "Invalid signature"}
      end

    {:ok, reply, options}
  end

  def authorized?(request, body) do
    case :cowboy_req.header("authorization", request) do
      <<
        "Signature ",
        sender::binary-size(32),
        " ",
        signature::binary-size(64)
      >> ->
        Crypto.valid_signature?(signature, body, sender)
      _ ->
        false
    end
  end

  def deploy(request, <<nonce::binary-size(4), code::binary>>) do
      %{
        address: address,
        contract_name: contract_name
      } = :cowboy_req.bindings(request)

      GenServer.call(VM, {:deploy, %{
        sender: sender(request),
        address: Base.decode16!(address, case: :lower),
        contract_name: contract_name,
        code: code,
      }})
  end

  def read_body(request) do
    {:ok, body, _headers} = :cowboy_req.read_body(request)
    body
  end

  def success(payload, request) do
    :cowboy_req.reply(
      200,
      %{"Content-Type" => "application/cbor"},
      payload,
      request
    )
  end

  def error(code, message, request) do
    :cowboy_req.reply(
      code,
      %{"Content-Type" => "text/plain"},
      message,
      request
    )
  end

  def run(request, <<
      nonce::binary-size(4),
      rpc::binary
      >>) do
        %{
          address: address,
          contract_name: contract_name
        } = :cowboy_req.bindings(request)
      case GenServer.call(VM, {:call, %{
        address: Base.decode16!(address, case: :lower),
        contract_name: contract_name,
        sender: sender(request),
        rpc: rpc,
        nonce: nonce,
      }}) do
        {:error, code, message} -> {:error, 500, message}
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
