Blacksmith.Models.Transaction.post(%{
  address: <<0::256>>,
  contract_name: :BaseToken,
  arguments: Cbor.encode([<<2::256>>, 50]),
  function: :transfer,
  nonce: 0,
  sender: <<1::256>>,
})
