pragma solidity ^0.5.0;
import "./utils/RSA.sol";

/**
 * @title RSAPublicModuliRegistry
 * @dev Allows accounts to register part of their RSA public key so their
 * signtuares can be verified later. An RSA public key is made up of
* modulus and an exponent. We assume that all public key exponents are set
* to a commonly used value: 65537 (0x010001). Accounts then only need to
* register their public modulus which saves space.
 */
contract RSAPublicModuliRegistry {
  using RSA for bytes;
  bytes constant RSA_PUBLIC_EXPONENT = hex"010001";
  uint constant RSA_PUBLIC_MODULUS_LENGTH = 256;
  mapping(address => bytes) public rsaPublicModuli;

  function setRSAPublicModulus(bytes memory publicModulus) public {
    require(publicModulus.length == RSA_PUBLIC_MODULUS_LENGTH);
    require(rsaPublicModuli[msg.sender].length == 0);
    rsaPublicModuli[msg.sender] = publicModulus;
  }

  function getRSAPublicModulus(address _address) public view returns (bytes memory) {
    return rsaPublicModuli[_address];
  }

  function verifyRSASignature(bytes memory _data, bytes memory _s,  address _address) public view returns (bool) {
    return _data.pkcs1Sha256VerifyRaw(
      _s,
      RSA_PUBLIC_EXPONENT,
      getRSAPublicModulus(_address)) == 0;
  }
}
