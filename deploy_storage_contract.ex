accounts = ExW3.accounts()
ExW3.balance(Enum.at(accounts, 0))
ExW3.block_number()
contract_file_name = "EllipitcoinStakingContract"
abi_file_name = Path.join(["test", "support", contract_file_name <> ".abi"])
bin_file_name = Path.join(["test", "support", contract_file_name <> ".hex"])
simple_storage_abi = ExW3.load_abi(abi_file_name)
simple_storage_bin = ExW3.load_bin(bin_file_name)
ExW3.Contract.start_link
ExW3.Contract.register(:SimpleStorage, abi: simple_storage_abi)
{:ok, address, tx_hash} = ExW3.Contract.deploy(:SimpleStorage, bin: simple_storage_bin, options: %{
  gas: 6721975,
  from: Enum.at(accounts, 0),
})
# ExW3.Contract.at(:SimpleStorage, address)
# ExW3.Contract.call(:SimpleStorage, :get)
# ExW3.Contract.send(:SimpleStorage, :set, [1], %{from: Enum.at(accounts, 0), gas: 50_000})
# IO.inspect ExW3.Contract.call(:SimpleStorage, :get)
