defmodule SystemContracts do
  alias Ellipticoind.Repo
  alias Ellipticoind.Models.Contract

  def deploy() do
    case Repo.get_by(Contract, name: :BaseToken) do
      nil -> %Contract{name: nil}
      contract -> contract
    end
    |> Contract.changeset(%{
      address: <<0::256>>,
      name: :BaseToken,
      code: Contract.base_contract_code(:BaseToken)
    })
    |> Repo.insert_or_update()
  end
end
