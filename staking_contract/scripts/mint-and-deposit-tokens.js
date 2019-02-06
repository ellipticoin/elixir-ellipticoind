require("@babel/register");
require('dotenv').config();
const {
  compile,
  submitTransaction,
} = require("../src/utils");
const Web3 = require("web3");
const util = require("ethereumjs-util");
const Transaction = require('ethereumjs-tx');
const web3 = new Web3(process.env.WEB3_URL);
const fs = require("fs");
const privateKey = new Buffer(process.env.PRIVATE_KEY, "hex");
const blacksmithPrivateKeys = process.env.BLACKSMITH_PRIVATE_KEYS.split(",").map((key) => new Buffer(key, "hex"));
const stakingContractAddress = "0xFd111e1B20c2C8A1BBF0B3bCd348A0aa88EBa901";
const stakingContractABIFilename = "build/contracts/EllipticoinStakingContract.json";
const tokenContractAddress = "0xa67d9E7390CFc5e413Ab42419ade8fD8BC1f2fF3"
const tokenContractABIFilename = "build/contracts/TestnetToken.json";
const amount = 100 * (10 ** 3);


let address = "0x" + util.privateToAddress(privateKey).toString("hex");

async function run() {
  const stakingAbi = JSON.parse(fs.readFileSync(stakingContractABIFilename)).abi;
  const stakingContract = new web3.eth.Contract(stakingAbi, stakingContractAddress)
  const tokenAbi = JSON.parse(fs.readFileSync(tokenContractABIFilename)).abi;
  const tokenContract = new web3.eth.Contract(tokenAbi, tokenContractAddress)

  console.log(await stakingContract.methods.token().call());
  blacksmithPrivateKeys.forEach(async (privateKey) => {
    let address = "0x" + util.privateToAddress(privateKey).toString("hex");
    await submitTransaction(tokenContract.methods.mint(address, amount).encodeABI(), tokenContractAddress, privateKey, web3);
    await submitTransaction(tokenContract.methods.approve(stakingContractAddress, amount).encodeABI(), tokenContractAddress, privateKey, web3);
    await submitTransaction(stakingContract.methods.deposit(amount).encodeABI(), stakingContractAddress, privateKey, web3);
    console.log(`Deposited ${amount / (10 **3)} tokens into ${address}`);
  });
}
 run();
