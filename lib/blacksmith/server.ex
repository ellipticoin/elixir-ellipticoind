defmodule Blacksmith.Server do
  use GRPC.Server, service: BlacksmithService.BlacksmithService.Service
  alias BlacksmithService.BalanceRequest
  alias BlacksmithService.BalanceResponse

  @spec get_balance(BalanceRequest.t(), GRPC.Server.Stream.t()) :: BalanceResponse.t()
  def get_balance(request, _stream) do
    balance = 10
    BalanceResponse.new(balance: balance)
  end
end
