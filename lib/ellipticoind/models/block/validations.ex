defmodule Ellipticoind.Models.Block.Validations do
  alias Ellipticoind.Models.Block

  def valid_next_block?(proposed_block) do
    valid_proof_of_work_value?(proposed_block) &&
      greater_than_best_block?(proposed_block)
  end

  def valid_proof_of_work_value?(proposed_block) do
    Hashfactor.valid_nonce?(
      Block.as_binary_pre_pow(proposed_block),
      proposed_block.proof_of_work_value
    )
  end

  def greater_than_best_block?(proposed_block) do
    proposed_block.number >= Block.next_block_number()
  end
end
