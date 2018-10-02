defmodule Blockchain do
  use Utils

  @db Db.Redis

  def initialize() do
    if !initialized?() do
      forge_genesis_block()
      deploy_base_contracts()
    end
  end

  def initialized?() do
    !is_nil(best_block_hash())
  end

  def deploy_base_contracts() do
    {:ok, redis} = Redix.start_link()

    VM.set_contract_code(
      redis,
      Constants.system_address(),
      Constants.base_api_name(),
      Constants.base_api_code()
    )

    VM.set_contract_code(
      redis,
      Constants.system_address(),
      Constants.base_token_name(),
      Constants.base_token_code()
    )

    VM.set_contract_code(
      redis,
      Constants.system_address(),
      Constants.user_contracts_name(),
      Constants.user_contracts_code()
    )

    VM.set_contract_code(
      redis,
      Constants.system_address(),
      Constants.human_readable_name_registry_name(),
      Constants.human_readable_name_registry_code()
    )
  end

  @doc """
  Forges the genesis block. Note the genesis block is just a `%Block{}`
  with default values set.
  """
  def forge_genesis_block() do
    forge(%Block{})
  end

  def forge(block) do
    block_hash = Block.hash(block)

    @db.set_map(block_hash, block)
    @db.set_binary("best_block_hash", block_hash)
    WebsocketHandler.broadcast(:blocks, block)
  end

  def get_latest_blocks(number) do
  end

  def finalize_block() do
    best_block = best_block()

    block = %Block{
      number: best_block.number + 1,
      parent_block: Block.hash(best_block),
      state_changes_hash: state_changes_hash()
    }

    forge(block)
    reset_state_changes()
  end

  def reset_state_changes(), do: @db.delete("state_changes")

  def best_block_hash() do
    @db.get_binary("best_block_hash") |> ok
  end

  def best_block() do
    @db.get_map(best_block_hash(), Block)
  end

  def state_changes_hash(), do: Crypto.hash(Enum.join(state_changes()))

  def state_changes(), do: @db.get_list("state_changes") |> ok
end
