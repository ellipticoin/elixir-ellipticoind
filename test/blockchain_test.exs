defmodule BlockchainTest do
  use ExUnit.Case

  test "Blockchain.last_n_blocks" do
    for number <- 1..5, do: Blockchain.insert(%Block{number: number})

    # Blockchain.forge()
  end
end
