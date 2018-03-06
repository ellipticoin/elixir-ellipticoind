defmodule BaseContractBenchmark do
  def transfer(db, receiver, amount) do
    func_and_args_with_signature = Elipticoin.FuncAndArgs
    .decode(@base_token_transfer)
    func_and_args = Map.put(func_and_args_with_signature, :signature, <<>>)

    # if Ed25519.valid_signature?(
    #   Map.get(func_and_args_with_signature, :signature),
    #   Elipticoin.FuncAndArgs.encode(func_and_args),
    #   Map.get(func_and_args_with_signature, :public_key)
    # ) do
      VM.run(db, @base_token_contract, "call", Base.decode16!("a2666d6574686f646a62616c616e63655f6f6666706172616d738143010203", case: :lower))
    # else
    #   IO.puts "Invalid Transaction signature"
    # end
  end

end

sender=<<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>
receiver=<<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2>>
base_token_transfer = Base.decode16!("0a087472616e7366657212240a2082a28a4e95ce0800db6c334628c1dae9fe168bf1197c5d3b9d612fef71ca73b010011a20b114ed4c88b61b46ff544e9120164cb5dc49a71157c212f76995bf1d6aecab0e22402f5a79c4f85cbd8a703a143c84f646fbf2858502270ed8ff8b42323b02ff836565e2a857f3d7ce6787dd076b3d8f0a4557334bd5fe5a2317c8b120a2c3c5440c", case: :lower)
base_token_contract = File.read!("base_contracts/base_token.wasm")

{:ok, db} = VM.open_db("tmp/blockchain.db")
# VM.run(db, base_token_contract, "_initialize", Elipticoin.InitializeArgs.encode(Elipticoin.InitializeArgs.new(initial_supply: 10000)))
# Benchee.run(%{
#   "base_token_transfer"    => fn -> transfer(db, receiver, 1) end,
# }, time: 1)
arg = Cbor.encode(%{method: :constructor, params: [100]})
IO.inspect arg
IO.inspect VM.run(db, base_token_contract, "call", arg)
