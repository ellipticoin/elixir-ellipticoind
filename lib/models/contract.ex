defmodule Models.Contract do
  @system_address Constants.system_address()

  use Ecto.Schema
  import Ecto.Changeset

  schema "contracts" do
    field(:code, :binary)
    timestamps()
  end

  def post(%{
        address: <<0::256>>,
        contract_name: contract_name,
        method: method,
        params: params,
        sender: sender
      }) do
    TransactionPool.add(%{
      code: system_code(contract_name),
      env: %{
        sender: sender,
        address: @system_address,
        contract_name: contract_name
      },
      method: method,
      params: params
    })
  end

  def get(%{
        address: <<0::256>>,
        contract_name: contract_name,
        method: method,
        params: params
      }) do
    VM.get(%{
      code: system_code(contract_name),
      env: %{
        address: Constants.system_address(),
        contract_name: contract_name
      },
      method: method,
      params: params
    })
  end

  def system_code(contract_name) do
    case contract_name do
      "BaseToken" -> Constants.base_token_code()
      "BaseApi" -> Constants.base_api_code()
      "UserContracts" -> Constants.user_contracts_code()
      "HumanReadableNameRegistery" -> Constants.human_readable_name_registry_code()
    end
  end

  def changeset(user, _params \\ %{}) do
    user
    |> validate_required([
      :code
    ])
  end
end
