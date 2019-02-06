defmodule Blacksmith.Models.Contract do
  @system_address Constants.system_address()

  use Ecto.Schema
  import Ecto.Changeset
  alias Blacksmith.Ecto.Types

  schema "contracts" do
    field(:address, :binary)
    field(:code, :binary)
    field(:name, Types.Atom)
    timestamps()
  end

  def post(%{
        address: <<0::256>>,
        contract_name: contract_name,
        function: function,
        arguments: arguments,
        sender: sender
      }) do
    # TransactionPool.add(%{
    #   code: system_code(contract_name),
    #   env: %{
    #     sender: sender,
    #     address: @system_address,
    #     contract_name: contract_name
    #   },
    #   method: method,
    #   params: params
    # })
  end

  def get(%{
        address: <<0::256>>,
        contract_name: contract_name,
        function: function,
        arguments: arguments
      }) do
    <<error_code::size(32), return_value::binary>> =
      VM.run(%{
        contract_code: base_contract_code(contract_name),
        contract_address: <<0::256>>,
        contract_name: contract_name,
        function: function,
        arguments: arguments,
        sender: <<>>
      })

    if error_code == 0 do
      {:ok, return_value}
    else
      {:error, error_code}
    end
  end

  def changeset(contract, params) do
    cast(contract, params, [:address, :code, :name])
    |> validate_required([:code])
    |> unique_constraint(:name, name: :contracts_address_name_index)
  end

  def base_contract_code(contract_name) do
    File.read!(
      Application.get_env(:blacksmith, :base_contracts_path) <>
        "/#{Macro.underscore(Atom.to_string(contract_name))}.wasm"
    )
  end
end
