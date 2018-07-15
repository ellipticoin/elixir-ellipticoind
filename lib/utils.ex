defmodule Utils do
  defmacro __using__(_) do
    quote do
      import Utils
    end
  end

  @doc """
  Extracts the value from a tagged tuple like {:ok, value}
  Raises the value from a tagged tuple like {:error, value}
  Raise the arguments else

  ## Examples
      iex> Utils.ok({:ok, 1})
      1
      iex> Utils.ok({:error, "some"})
      ** (RuntimeError) some

  """
  def ok({:ok, x}), do: x
  def ok({:error, x}), do: raise x
  def ok(x), do: raise x
end
