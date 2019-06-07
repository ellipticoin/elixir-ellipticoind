defmodule SystemContracts do
  alias Ellipticoind.Storage
  alias Ellipticoind.Models.Contract

  def deploy() do
    Storage.set(0, <<0::256>>, :BaseToken, "_code", Contract.base_contract_code(:BaseToken))
  end
end
