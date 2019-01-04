pragma solidity ^0.5.0;
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "./Depositable.sol";
import "./RSAPublicModuliRegistry.sol";
import "./utils/ECDSA.sol";

contract EllipticoinStakingContract is Depositable, ECDSA, RSAPublicModuliRegistry {
  bytes32 public blockHash;
  uint public blockNumber;
  bytes public lastSignature;

  constructor(ERC20 _token, bytes memory randomSeed) Depositable(_token) public {
    lastSignature = randomSeed;
  }

  function submitBlock(
    uint _blockNumber,
    bytes32 _blockHash,
    bytes memory signature
  ) public {
    require(msg.sender == winner());
    require(verifyRSASignature(lastSignature, signature, msg.sender));
    blockNumber = _blockNumber;
    blockHash = _blockHash;
    lastSignature = signature;
  }

  function winner() public view returns (address) {
    uint randomUint = bytesToUint(lastSignature);
    uint winningValue = randomUint % totalStake();
    uint value = 0;
    uint i = 0;
    do {
      value += balanceOf(addresses[i]);
      i += 1;
    } while (value < winningValue);

    return addresses[i - 1];
  }

  function bytesToUint(bytes memory _bytes) public pure returns (uint256) {
    require(_bytes.length >= 32);
    uint256 tempUint;

    assembly {
      tempUint := mload(add(_bytes, 0x20))
    }

    return tempUint;
  }
}
