defmodule Ellipticoind.Memory do
  import Binary
  @key "memory"

  def get_value(address, contract_name, key) do
    memory = get(address, contract_name, key)

    if memory == [] do
      nil
    else
      Cbor.decode!(memory)
    end
  end

  def get(address, contract_name, key) do
    memory_key = @key <> ":" <> address <> (Atom.to_string(contract_name) |> pad_trailing(32)) <> key
    case Redis.get_reverse_ordered_set_values(
      memory_key,
      "+inf",
      "-inf",
      0,
      1
    ) do
      [hash_key] -> Redis.get_hash_value("memory_hash", hash_key)
      _ -> []
    end
  end

  def set(address, contract_name, block_number, key, value) do
    key = address <> (Atom.to_string(contract_name) |> pad_trailing(32)) <> key
    memory_key =  @key <> ":" <> key
    hash_key = <<block_number::little-size(64)>> <> key
    Redis.add_to_sorted_set(
      memory_key,
      0,
      hash_key
    )

    Redis.set_hash_value(
      "memory_hash",
      hash_key,
      value
    )
  end

end
