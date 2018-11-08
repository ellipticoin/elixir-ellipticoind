defmodule EthereumContracts do
  def deploy(module_name, args \\ []) do
    contract_name =
      to_string(module_name)
      |> String.split(".")
      |> List.last()

    abi_file_name = Path.join(["priv", "ethereum_contracts", "#{contract_name}.abi"])
    bin_file_name = Path.join(["priv", "ethereum_contracts", "#{contract_name}.hex"])
    abi = ExW3.load_abi(abi_file_name)
    bin = ExW3.load_bin(bin_file_name)
    ExW3.Contract.register(module_name, abi: abi)

    {:ok, address, tx_hash} =
      ExW3.Contract.deploy(module_name,
        bin: bin,
        args: args,
        options: %{
          gas: 6_721_975,
          from: ExW3.accounts() |> Enum.at(0)
        }
      )

    ExW3.Contract.at(module_name, address)
    {:ok, address}
  end
end
