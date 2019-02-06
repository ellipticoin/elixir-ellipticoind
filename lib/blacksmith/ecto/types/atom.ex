defmodule Blacksmith.Ecto.Types.Atom do
  @behaviour Ecto.Type

  def type, do: :string

  def cast(value) when is_binary(value) or is_atom(value) do
    {:ok, atomize(value)}
  end

  def load(string) when is_binary(string) do
    {:ok, atomize(string)}
  end

  def dump(atom) when is_atom(atom) or is_binary(atom) do
    {:ok, stringify(atom)}
  end

  defp atomize(string) when is_binary(string), do: String.to_atom(string)
  defp atomize(atom), do: atom

  defp stringify(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp stringify(string), do: string
end
