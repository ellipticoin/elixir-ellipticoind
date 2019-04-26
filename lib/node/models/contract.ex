defmodule Node.Models.Contract do
  use Agent
  use Ecto.Schema
  import Ecto.Changeset
  alias Node.Repo
  alias Node.Models.Contract
  alias Node.Ecto.Types

  @primary_key false
  schema "contracts" do
    field(:address, :binary, primary_key: true)
    field(:name, Types.Atom, primary_key: true)
    field(:code, :binary)
    timestamps()
  end

  def changeset(contract, params) do
    cast(contract, params, [:address, :code, :name])
    |> validate_required([:code])
    |> unique_constraint(:name, name: :contracts_address_name_index)
  end

  def find_by(parameters) do
    defaults = %{address: <<0::256>>, name: :BaseToken}

    parameters =
      Map.merge(parameters, defaults)
      |> Enum.into(%{})

    Repo.get_by(__MODULE__, parameters)
  end

  def base_contract_code(contract_name) do
    File.read!(
      Application.get_env(:node, :base_contracts_path) <>
        "/#{Macro.underscore(Atom.to_string(contract_name))}.wasm"
    )
  end
end
