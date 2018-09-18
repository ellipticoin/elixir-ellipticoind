defmodule BlockchainTest do

  use ExUnit.Case

  test "Blockchain.last_n_blocks" do
    for number <- 1..5, do: Blockchain.insert(
      %Block{number: number}
    )

    IO.inspect Blockchain.get_latest_blocks(3)
    # Blockchain.forge()
  end
end
