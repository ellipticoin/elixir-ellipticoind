var TestnetToken = artifacts.require("./utils/TestnetToken.sol");
var RSA = artifacts.require("./utils/RSA.sol");
var RSAPublicModuliRegistry = artifacts.require("./RSAPublicModuliRegistry.sol");
var EllipticoinStakingContract = artifacts.require("./EllipticoinStakingContract.sol");

module.exports = async function(deployer) {
  await deployer.deploy(TestnetToken, "[Testnet] DAI", "TESTDAI", 12)
  await TestnetToken.deployed()
  await deployer.deploy(RSA);
  await deployer.link(RSA, EllipticoinStakingContract);
  await deployer.link(RSA, RSAPublicModuliRegistry);
  await deployer.deploy(RSAPublicModuliRegistry);
  await deployer.deploy(
    EllipticoinStakingContract,
    TestnetToken.address,
    "0x" + Buffer(128).toString("hex")
  );
  let ellipticoinStakingContract = await EllipticoinStakingContract.deployed();
};
