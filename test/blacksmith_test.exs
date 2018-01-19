defmodule BlacksmithTest do
  use ExUnit.Case
  doctest Blacksmith

  test "greets the world" do
    assert Blacksmith.hello() == :world
  end
end
