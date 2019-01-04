contract_address = <<0::256>>
contract_name = :BaseToken
contract = Blacksmith.Repo.get_by(Blacksmith.Models.Contract,
  address: <<0::256>>,
  name: Atom.to_string(contract_name)
)
IO.inspect VM.run(%{
  contract_address: contract_address,
  contract_name: contract_name,
  contract_code: contract.code,
  arguments: [<<2::256>>],
  function: :balance_of,
  sender: <<>>,
})
