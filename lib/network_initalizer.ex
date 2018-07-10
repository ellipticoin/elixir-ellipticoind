defmodule NetworkInitializer do

  def run(redis) do
    VM.set_contract_code(
      redis,
      Constants.system_address(),
      Constants.base_token_name(),
      Constants.base_token_code()
    )

    VM.set_contract_code(
      redis,
      Constants.system_address(),
      Constants.base_api_name(),
      Constants.base_api_code()
    )

    VM.set_contract_code(
      redis,
      Constants.system_address(),
      Constants.human_readable_name_registry_name(),
      Constants.human_readable_name_registry_code()
    )
  end

end
