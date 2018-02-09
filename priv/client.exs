Blacksmith.Account.add_balance()
# {:ok, channel} = GRPC.Stub.connect("localhost:4047")
#
# {:ok, reply} =
#   channel
#   |> BlacksmithService.BlacksmithService.Stub.get_balance(
#     BlacksmithService.BalanceRequest.new(name: "grpc-elixir")
#   )
#
# IO.inspect(reply)
