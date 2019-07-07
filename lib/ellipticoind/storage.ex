defmodule Ellipticoind.Storage do
  alias Ellipticoind.TransactionProcessor
  alias Ellipticoind.BlockIndex
  import Binary
  @prefix "storage"

  def get_value(address, contract_name, key) do
    memory = get(address, contract_name, key)

    if memory == [] do
      nil
    else
      Cbor.decode!(memory)
    end
  end

  def set(block_number, address, contract_name, key, value),
    do: set(block_number, to_key(address, contract_name, key), value)

  def get(address, contract_name, key), do: get(to_key(address, contract_name, key))

  def to_key(address, contract_name, key),
    do: address <> (Atom.to_string(contract_name) |> pad_trailing(32)) <> key

  def get(key) do
    if block_number = BlockIndex.get_latest(@prefix, key) do
      RocksDB.get(block_number, key)
    else
      []
    end
  end

  def set(block_number, key, value) do
    BlockIndex.add(@prefix, key, block_number)
    TransactionProcessor.set_storage(block_number, key, value)
  end
end
