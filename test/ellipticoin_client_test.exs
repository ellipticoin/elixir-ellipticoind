defmodule EllipticoinClientTest do
  import Test.Utils
  use ExUnit.Case

  setup do
    checkout_repo()

    :ok
  end

  @tag :network
  test "EllipticoinClient.get_block" do
    IO.inspect EllipticoinClient.get_block(1)
  end
end
