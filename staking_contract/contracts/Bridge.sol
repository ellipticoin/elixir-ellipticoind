pragma solidity ^0.5.0;
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "./utils/ArrayHelper.sol";

contract Bridge {
  mapping (uint256 => ERC20[]) public mintedCoinTokenAddresses;
  mapping (uint256 => bytes32[]) public mintedCoinRecipientAddresses;
  mapping (uint256 => uint256[]) public mintedCoinValues;
  mapping (uint256 => uint32) public mintedCoinLengths;
  uint256[] public mintedBlocks;
  uint256 public mintedBlocksLength;

  function mint(ERC20 tokenAddress, bytes32 recipient, uint256 amount) public {
      tokenAddress.transferFrom(msg.sender, address(this), amount);
      mintedCoinTokenAddresses[block.number].push(tokenAddress);
      mintedCoinRecipientAddresses[block.number].push(recipient);
      mintedCoinValues[block.number].push(amount);
      mintedCoinLengths[block.number]++;
      mintedBlocks.push(block.number);
      mintedBlocksLength++;
  }
}
