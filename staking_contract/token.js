require('@babel/register');
require('dotenv').config()
const {
  fundAndRegisterWithStakingContract,
  submitTransaction,
} = require("./src/utils");
var Promise = require("bluebird");
const fs = require('fs');
var util = require("ethereumjs-util");
const stakingFile = fs.readFileSync('./build/contracts/EllipticoinStakingContract.json', "utf8");
const tokenFile = fs.readFileSync('./build/contracts/TestnetToken.json', "utf8");
var Web3 = require('web3');
const {
  PRIVATE_KEY,
  WEB3_URL
} = process.env;
var web3 = new Web3(WEB3_URL);
const blacksmithPrivateKeys = process.env.BLACKSMITH_PRIVATE_KEYS.split(",").map((privateKey) => Buffer.from(privateKey, "hex"));

async function run() {
  const stakingFile = fs.readFileSync('./build/contracts/EllipticoinStakingContract.json', "utf8");
  const stakingAbi = JSON.parse(stakingFile).abi;
  const stakingContract = new web3.eth.Contract(stakingAbi, "0xEB66858CDF9eCA400Cc2e676D3fC447a97e806Af");
  await fundAndRegisterWithStakingContract(stakingContract._address, 100);
  console.log(`totalStake: ${await stakingContract.methods.totalStake().call()}`)
  console.log(await stakingContract.methods.getRSAPublicModulus("0x28af5461cad683041bd3666851f2c066277088a5"))
}
run();
