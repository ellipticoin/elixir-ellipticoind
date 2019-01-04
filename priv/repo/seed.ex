def system_code(file_name) do
  File.read!(Application.get_env(:blacksmith, :base_contracts_path) <> "/" <> file_name)
end
Enum.each([
  "BaseToken",
  "BaseApi",
  "UserContracts",
  "HumanReadableNameRegistery",
], fn(contract_name) ->
  %Blacksmith.Models.Contract{
    address: <<0::265>>,
    name: contract_name,
    code: system_code(contract_name),
  }
  |> Blacksmith.Repo.insert!()
end)
