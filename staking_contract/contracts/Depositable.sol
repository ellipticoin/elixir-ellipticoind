pragma solidity ^0.5.0;
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "./utils/ArrayHelper.sol";

contract Depositable is ArrayHelper {
  ERC20 public token; 
  address[] public addresses;
  mapping(address => uint) public balances;

  constructor(ERC20 _token) public {
    token = _token;
  }

  function push() public {
    addresses.push(msg.sender);
  }

  function deposit(uint amount) public {
    require(token.balanceOf(msg.sender) >= amount);
    balances[msg.sender] += amount;
    addresses.push(msg.sender);
    token.transferFrom(msg.sender, address(this), amount);
  }

  function withdraw(uint amount) public {
    require(balances[msg.sender] >= amount);
    balances[msg.sender] -= amount;
    token.approve(address(this), amount);
    token.transferFrom(address(this), msg.sender, amount);

    if(balances[msg.sender] == 0) {
      addresses = removeValue(addresses, msg.sender);
    }
  }

  function balanceOf(address _owner) public view returns (uint256) {
    return balances[_owner];
  }

  function totalStake() public view returns (uint _totalStake){
    for(uint i = 0; i < addresses.length; i++) {
      _totalStake += balances[addresses[i]];
    }
  }

  function addressesLength() public view returns (uint){
    return addresses.length;
  }
}
