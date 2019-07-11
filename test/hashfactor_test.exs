defmodule HashfactorTest do
  use ExUnit.Case

  test "Hashfactor" do
    data = <<1, 2, 3>>
    nonce = Hashfactor.run(data)
    assert Hashfactor.valid_nonce?(data, nonce)
  end
end
