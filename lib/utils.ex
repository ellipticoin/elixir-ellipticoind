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
  def ok({:error, x}), do: raise(x)
  def ok(x), do: raise(x)

  def private_key_to_address(private_key) do
    private_key_to_public_key(private_key)
      |> ExthCrypto.Key.der_to_raw()
      |> ExthCrypto.Hash.Keccak.kec()
      |> EVM.Helpers.take_n_last_bytes(20)
  end

  def private_key_to_public_key(private_key) do
    private_key
      |> ExthCrypto.Signature.get_public_key()
      |> elem(1)
  end
end
