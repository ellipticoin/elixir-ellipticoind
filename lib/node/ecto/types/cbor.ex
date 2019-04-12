defmodule Node.Ecto.Types.Cbor do
  @behaviour Ecto.Type

  def type, do: :binary
  def cast(value), do: {:ok, value}
  def load(value), do: Cbor.decode(value)
  def dump(value), do: {:ok, Cbor.encode(value)}
end
