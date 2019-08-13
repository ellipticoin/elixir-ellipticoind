defmodule Ellipticoind.Models.Block.Validations do
  alias Ellipticoind.Models.Block
  alias Ellipticoind.Views.BlockView

  def valid_next_block?(proposed_block) do
    valid_proof_of_work_value?(proposed_block) &&
      greater_than_best_block?(proposed_block)
  end

  def valid_proof_of_work_value?(proposed_block) do
    Hashfactor.valid_nonce?(
      Cbor.encode(BlockView.as_map_pre_pow(proposed_block)),
      proposed_block.proof_of_work_value
    )
  end

  def greater_than_best_block?(proposed_block) do
    proposed_block.number >= Block.next_block_number()
  end
end
