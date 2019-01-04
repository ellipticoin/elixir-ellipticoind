pragma solidity ^0.5.0;

contract ECDSA {
  struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  function verifySignature(address _address, bytes memory _bytes, string memory length, Signature memory signature) internal pure returns(bool) {
    return ecrecover(
      signatureHash(_bytes, length),
      signature.v,
      signature.r,
      signature.s
    ) == _address;
  }

  function signatureHash(bytes memory _bytes, string memory length) internal pure returns (bytes32) {
    bytes memory prefix = "\x19Ethereum Signed Message:\n";
    return keccak256(abi.encodePacked(prefix, length, _bytes));
  }
}
