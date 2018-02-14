defmodule BlacksmithTest do
  @base_token_transfer Base.decode16!("0a087472616e7366657212240a2082a28a4e95ce0800db6c334628c1dae9fe168bf1197c5d3b9d612fef71ca73b010011a20b114ed4c88b61b46ff544e9120164cb5dc49a71157c212f76995bf1d6aecab0e22402f5a79c4f85cbd8a703a143c84f646fbf2858502270ed8ff8b42323b02ff836565e2a857f3d7ce6787dd076b3d8f0a4557334bd5fe5a2317c8b120a2c3c5440c", case: :lower)
  @base_token_contract File.read!("test/support/base_token.wasm")
  use ExUnit.Case

  test "run benchmarks" do
    # Benchee.run(%{
    #   "base_token_transfer"    => &transfer/0,
    # }, time: 1)
    transfer()
  end

  def transfer do
    func_and_args_with_signature = Elipticoin.FuncAndArgs
    .decode(@base_token_transfer)
    func_and_args = Map.put(func_and_args_with_signature, :signature, <<>>)

    if Ed25519.valid_signature?(
      Map.get(func_and_args_with_signature, :signature),
      Elipticoin.FuncAndArgs.encode(func_and_args),
      Map.get(func_and_args_with_signature, :public_key)
    ) do
      # VM
    else
      IO.puts "Invalid Transaction signature"
    end
  end
end
