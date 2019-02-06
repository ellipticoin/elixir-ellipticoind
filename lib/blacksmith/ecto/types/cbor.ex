defmodule Blacksmith.Ecto.Types.Cbor do
  @behaviour Ecto.Type

  def type, do: :binary

  def cast(value), do: {:ok, Cbor.encode(value)}
  def load(value), do: Cbor.decode(value)
  def dump(value), do: {:ok, value}
end
