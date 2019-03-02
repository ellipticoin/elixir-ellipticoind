defmodule Node.Models.Block.Validations do
  alias Node.Repo
  alias Node.Models.Block

  def valid_next_block?(proposed_block, transaction_results) do
    valid_transaction_results?(proposed_block, transaction_results) &&
      valid_proof_of_work_value?(proposed_block) &&
        greater_than_best_block?(proposed_block)
  end

  def valid_transaction_results?(proposed_block, transaction_results) do
    proposed_block.transactions == transaction_results.transactions &&
    proposed_block.changeset_hash == transaction_results.changeset_hash
  end

  def valid_proof_of_work_value?(proposed_block) do
    Hashfactor.valid_nonce?(
      Block.as_binary_pre_pow(proposed_block),
      Config.hashfactor_target(),
      proposed_block.proof_of_work_value
    )
  end

  def greater_than_best_block?(proposed_block) do
    best_block = Block.best() |> Repo.one()

    is_nil(best_block) || proposed_block.number > best_block.number
  end
end
