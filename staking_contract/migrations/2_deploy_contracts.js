const {
  fundAndRegisterWithStakingContract,
  submitTransaction,
} = require("../src/utils");
const Web3 = require("web3");
var Promise = require("bluebird");
const HDWalletProvider = require("truffle-hdwallet-provider");
var TestnetToken = artifacts.require("./utils/TestnetToken.sol");
var SimpleStorage = artifacts.require("./SimpleStorage.sol");
var util = require("ethereumjs-util");
var RSA = artifacts.require("./utils/RSA.sol");
var RSAPublicModuliRegistry = artifacts.require("./RSAPublicModuliRegistry.sol");
var EllipticoinStakingContract = artifacts.require("./EllipticoinStakingContract.sol");
const {
  PRIVATE_KEY,
  WEB3_URL
} = process.env;
const blacksmithPrivateKeys = process.env.BLACKSMITH_PRIVATE_KEYS.split(",").map((privateKey) => Buffer.from(privateKey, "hex"));
const amount = 100 * (10 ** 3);

module.exports = async function(deployer, network) {
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
  if(network == "rinkeby") {
    await fundAndRegisterWithStakingContract(ellipticoinStakingContract.address, 100);
  }
  console.log(`totalStake: ${await ellipticoinStakingContract.totalStake.call()}`)
};

