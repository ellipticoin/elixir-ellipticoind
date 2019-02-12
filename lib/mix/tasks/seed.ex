defmodule Mix.Tasks.Seed do
  alias Blacksmith.Models.Contract
  alias Blacksmith.Repo
  use Mix.Task

  @shortdoc "Seeds the database"
  def run(_) do
    Mix.Task.run("app.start")

    Enum.each(
      [
        "BaseToken",
        "BaseApi",
        "UserContracts"
      ],
      &create_contract/1
    )
  end

  def create_contract(contract_name) do
    Contract.changeset(
      %Contract{},
      %{
        address: <<0::256>>,
        name: contract_name,
        code: Contract.base_contract_code(contract_name)
      }
    )
    |> Repo.insert!()
  end
end
