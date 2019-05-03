Enum.each([
  "BaseToken",
  "BaseApi",
  "UserContracts",
  "HumanReadableNameRegistry",
], fn(contract_name) ->
  %Ellipticoind.Models.Contract{
    address: <<0::256>>,
    name: contract_name,
    code: File.read!(Application.get_env(:ellipticoind, :base_contracts_path) <> "/" <> Macro.underscore(contract_name) <> ".wasm"),
  }
  |> Ellipticoind.Repo.insert!()
end)
