block_hash = Base.decode16!("D2F673028681EA277726AC3AFF96B4B3E4606551B66BCE1A61A2832171475634")

<<r::bytes-size(32), s::bytes-size(32), v::8-integer>> =
  Base.decode16!(
    "13CCB1C4E01E76D4421A316FF8D7A175E9D77FB9285A62389B1E590F9F603AA6057CF3A933DA29E7ECFD69CD0C9CBAE696646D3959DFBEBF4D483930E5EBA01201"
  )

abi_encoded_data = ABI.encode("submitBlock(bytes32,uint8,bytes32,bytes32)", [block_hash, v, r, s])
contract_address = Application.fetch_env!(:blacksmith, :staking_contract_address)
ethereum_private_key = Application.fetch_env!(:blacksmith, :ethereum_private_key)

# IO.inspect contract_address |> Base.encode16, label: "contract address"
# IO.inspect v, label: "v"
# IO.inspect r |> Base.encode16, label: "r"
# IO.inspect s |> Base.encode16, label: "s"
# IO.inspect block_hash |> Base.encode16, label: "block_hash"

{:ok, transaction_count} =
  Ethereumex.WebSocketClient.eth_get_transaction_count(
    Ethereum.Helpers.bytes_to_hex(Ethereum.Helpers.my_ethereum_address())
  )

# IO.inspect (Ethereum.Helpers.hex_to_int(transaction_count) + 1), label: "noce"
transaction_data =
  %Blockchain.Transaction{
    data: abi_encoded_data,
    gas_price: 20_000_000_000,
    gas_limit: 4_712_388,
    data: abi_encoded_data,
    nonce: Ethereum.Helpers.hex_to_int(transaction_count),
    to: contract_address,
    value: 0
  }
  |> Blockchain.Transaction.Signature.sign_transaction(ethereum_private_key)
  |> Blockchain.Transaction.serialize()
  |> ExRLP.encode()
  |> Base.encode16(case: :lower)

IO.puts("0x" <> transaction_data)
IO.inspect(Ethereumex.WebSocketClient.eth_send_raw_transaction("0x" <> transaction_data))
