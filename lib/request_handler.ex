defmodule RequestHandler do
  @base_token_contract File.read!("base_contracts/base_token.wasm")

  def init(request, options) do
    if (:cowboy_req.method(request) == "POST") do
      headers = %{"Content-Type" => "application/cbor"}
      {:ok, body, _headers} = :cowboy_req.read_body(request)
      {:ok, result} = GenServer.call(VM, {:run, body})
      request2 = :cowboy_req.reply(200, headers, result, request)
      {:ok, request2, options}
    end
  end
end
