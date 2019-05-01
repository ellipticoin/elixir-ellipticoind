defmodule Node.Models.Block.TransactionResultValidations do
  def valid_transaction_results?(block, transaction_results) do
    !Enum.any?(transaction_errors(block, transaction_results))
  end

  def transaction_errors(block, transaction_results) do
    Enum.concat([
      changeset_errors(block, transaction_results.changeset_hash),
      return_code_errors(block, transaction_results.transactions),
      return_value_errors(block, transaction_results.transactions)
    ])
  end

  def transaction_errors(block, transactions, changeset_hash) do
    Enum.concat([
      changeset_errors(block, changeset_hash),
      return_code_errors(block, transactions),
      return_value_errors(block, transactions)
    ])
  end

  def changeset_errors(block, changeset_hash) do
    if block.changeset_hash != changeset_hash do
      [{:changeset_hash_mismatch, changeset_hash, block.changeset_hash}]
    else
      []
    end
  end

  def return_value_errors(block, transactions) do
    Enum.zip(block.transactions, transactions)
    |> Enum.reduce([], fn {proposed_transaction, transaction}, errors ->
      if proposed_transaction.return_value != transaction.return_value do
        [
          {
            :return_value_mismatch,
            transaction.return_value,
            proposed_transaction.return_value
          }
          | errors
        ]
      else
        errors
      end
    end)
  end

  def return_code_errors(block, transactions) do
    Enum.zip(block.transactions, transactions)
    |> Enum.reduce([], fn {proposed_transaction, transaction}, errors ->
      if proposed_transaction.return_code != transaction.return_code do
        [
          {
            :return_code_mismatch,
            transaction.return_code,
            proposed_transaction.return_code
          }
          | errors
        ]
      else
        errors
      end
    end)
  end
end
