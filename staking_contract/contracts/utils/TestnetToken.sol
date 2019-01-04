pragma solidity ^0.5.0;
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";

contract TestnetToken is ERC20Detailed, ERC20Mintable {
  constructor(string memory name, string memory symbol, uint8 decimals)
  ERC20Detailed(name, symbol, decimals)
  public {}
   // Allow anyone to mint testnet tokens
  function isMinter(address /* account */) public view returns (bool) {
    return true;
  }
}
