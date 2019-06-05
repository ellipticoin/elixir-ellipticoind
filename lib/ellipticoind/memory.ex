defmodule Ellipticoind.Memory do
  alias Ellipticoind.BlockIndex
  import Binary
  @prefix "memory"

  def get_value(address, contract_name, key) do
    memory = get(address, contract_name, key)

    if memory == [] do
      nil
    else
      Cbor.decode!(memory)
    end
  end

  def get(address, contract_name, key), do: get(to_key(address, contract_name, key))

  def to_key(address, contract_name, key),
    do: address <> (Atom.to_string(contract_name) |> pad_trailing(32)) <> key

  def get(key) do
    if block_number = BlockIndex.get_latest(@prefix, key) do
      Redis.get_hash_value(
        "memory",
        <<block_number::little-size(64)>> <> key
      )
    else
      []
    end
  end

  def set(address, contract_name, block_number, key, value) do
    key = address <> (Atom.to_string(contract_name) |> pad_trailing(32)) <> key
    BlockIndex.set_at_block(@prefix, key, block_number)

    Redis.set_hash_value(
      "memory",
      <<block_number::little-size(64)>> <> key,
      value
    )
  end
end
