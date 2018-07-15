defmodule Blockchain do
  use Utils

  @my_address Base.decode16!("509c3480af8118842da87369eb616eb7b158724927c212b676c41ce6430d334a", case: :lower)

  def initialize(redis) do
    if !initialized?(redis) do
      forge_genesis_block(redis)
      deploy_base_contracts(redis)
    end
  end

  def deploy_base_contracts(redis) do
    VM.set_contract_code(
      redis,
      Constants.system_address(),
      Constants.base_token_name(),
      Constants.base_token_code()
    )

    VM.set_contract_code(
      redis,
      Constants.system_address(),
      Constants.base_api_name(),
      Constants.base_api_code()
    )

    VM.set_contract_code(
      redis,
      Constants.system_address(),
      Constants.human_readable_name_registry_name(),
      Constants.human_readable_name_registry_code()
    )

  end

  @doc"""
  Forges the genesis block. Note the genesis block is just a `%Block{}`
  with default values set.
  """
  def forge_genesis_block(redis) do
    forge(redis, %Block{})
  end

  def forge(redis, block) do
    Redis.hset(redis, Block.hash(block), Map.from_struct(block))
    Redis.set(redis, "best_block_hash", Block.hash(block))
  end

  def initialized?(redis) do
    !!best_block_hash(redis)
  end

  def finalize_block(redis) do
    best_block = best_block(redis)
    block = %Block{
      number: best_block.number + 1,
      parent_block: Block.hash(best_block),
      state_changes_hash: state_changes_hash(redis)
    }

    forge(redis, block)
    reset_state_changes(redis)
  end

  def reset_state_changes(redis), do:
    Redis.del(redis, "state_changes")

  def best_block_hash(redis) do
    Redis.get(redis, "best_block_hash") |> ok
  end

  def best_block(redis), do:
    Redis.hgetall(redis, best_block_hash(redis))

  def state_changes_hash(redis), do:
    Crypto.hash!(Enum.join(state_changes(redis)))

  def state_changes(redis), do:
    Redis.lrange(redis, "state_changes", 0, -1) |> ok
end
