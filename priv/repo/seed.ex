Enum.each([
  "BaseToken",
  "BaseApi",
  "UserContracts",
  "HumanReadableNameRegistry",
], fn(contract_name) ->
  %Node.Models.Contract{
    address: <<0::256>>,
    name: contract_name,
    code: File.read!(Application.get_env(:node, :base_contracts_path) <> "/" <> Macro.underscore(contract_name) <> ".wasm"),
  }
  |> Node.Repo.insert!()
end)
