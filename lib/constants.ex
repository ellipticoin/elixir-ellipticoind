defmodule Constants do
  @system_address <<0::256>>
  @genisis_block_hash <<0::256>>
  @base_api_name "BaseApi"
  @base_token_name "BaseToken"
  @user_contracts_name "UserContracts"
  @human_readable_name_registry_name "HumanReadableNameRegistery"

  def base_api_name(), do: @base_api_name
  def base_token_name(), do: @base_token_name
  def user_contracts_name(), do: @user_contracts_name
  def human_readable_name_registry_name(), do: @human_readable_name_registry_name
  def user_contracts_code(), do: contract_code("user_contracts.wasm")
  def base_token_code(), do: contract_code("base_token.wasm")
  def base_api_code(), do: contract_code("base_api.wasm")
  def human_readable_name_registry_code(), do: contract_code("human_readable_name_registry.wasm")
  def system_address(), do: @system_address

  def contract_code(file_name) do
    File.read!(Application.get_env(:blacksmith, :base_contracts_path) <> "/" <> file_name)
  end
end
