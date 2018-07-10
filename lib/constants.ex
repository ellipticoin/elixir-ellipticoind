defmodule Constants do
  @system_address  Base.decode16!("0000000000000000000000000000000000000000000000000000000000000000", case: :lower)
  @genisis_block_hash Base.decode16!("0000000000000000000000000000000000000000000000000000000000000000", case: :lower)
  @base_token_name "BaseToken"
  @base_api_name "BaseApi"
  @human_readable_name_registry_name "HumanReadableNameRegistery"
  @base_token_code File.read!(Application.get_env(:blacksmith, :base_contracts_path) <> "/base_token.wasm")
  @base_api_code File.read!(Application.get_env(:blacksmith, :base_contracts_path) <> "/base_api.wasm")
  @human_readable_name_registry_code File.read!(Application.get_env(:blacksmith, :base_contracts_path) <> "/human_readable_name_registry.wasm")

  def base_token_name(), do: @base_token_name
  def base_api_name(), do: @base_api_name
  def human_readable_name_registry_name(), do: @human_readable_name_registry_name
  def base_token_code(), do: @base_token_code
  def base_api_code(), do: @base_api_code
  def human_readable_name_registry_code(), do: @human_readable_name_registry_code
  def system_address(), do: @system_address
end
