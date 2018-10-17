defmodule Test.Utils do
  import Binary

  def set_balances(balances) do
    token_balance_address = Constants.system_address() <> (Constants.base_token_name() |> pad_trailing(32))

    for {address, balance} <- balances do
      Redis.set_binary(token_balance_address <> address, <<balance::little-size(64)>>)
    end
  end
end
