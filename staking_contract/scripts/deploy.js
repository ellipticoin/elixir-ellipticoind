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
var mkdirp = require('mkdirp');
const path = require('path');
const tokenContractPath = "utils/TestnetToken.sol";
const tokenAddress = "0xA1FB77a212419bfE1B58E906DC39993823b424EC";
const tokenName = "[testnet] DAI Token";
const tokenSymbol = "DAI"
const tokenDecimals = 3;
const tokenSupply = 100 * (10 ** tokenDecimals);
const amount = 100 * (10 ** 3);
const tokenContractABIFilename = "dist/TestnetToken.abi";
const stakingContractABIFilename = "dist/EllipticoinStakingContract.abi";
const randomSeed = web3.utils.randomHex(32);
const privateKey = new Buffer(process.env.PRIVATE_KEY, "hex");
const contractFileName = "EllipticoinStakingContract.sol";
const distPath = "./dist";
const blacksmithPrivateKeys = process.env.BLACKSMITH_PRIVATE_KEYS.split(",").map((key) => new Buffer(key, "hex"));

let address = "0x" + util.privateToAddress(privateKey).toString("hex");

async function build() {
  let [contract, bytecode] = await compile(web3, contractFileName);
  const bytecodeBytes = Buffer.from(bytecode, "hex");
  const bytecodeFileName = contractFileName.substr(0, contractFileName.lastIndexOf(".")) + ".hex";
  const abiFileName = contractFileName.substr(0, contractFileName.lastIndexOf(".")) + ".abi";

  fs.writeFileSync(`${distPath}/${bytecodeFileName}`, bytecode);
  console.log(`Wrote ${distPath}/${bytecodeFileName}`)
  fs.writeFileSync(`${distPath}/${abiFileName}`, JSON.stringify(contract._jsonInterface));
  console.log(`Wrote ${distPath}/${abiFileName}`)
}

async function deployToken() {
  let [contract, bytecode] = await compile(web3, tokenContractPath);
  let {contractAddress} = await submitTransaction("0x" + contract.deploy({
    data: bytecode,
    arguments: [tokenName, tokenSymbol, tokenDecimals],
  }).encodeABI(), null, privateKey, web3);
  const contractFileName = path.parse(tokenContractPath).base;
  const abiFileName = (contractFileName).substr(0, contractFileName.lastIndexOf(".")) + ".abi";
  const abiPath = `${distPath}/${abiFileName}`;
  mkdirp(distPath);
  fs.writeFileSync(abiPath, JSON.stringify(contract._jsonInterface));
  console.log(`Wrote ${abiPath}`)
  return contractAddress;
}

async function deployStakingContract(tokenAddress) {
  let [contract, bytecode] = await compile(web3, "EllipticoinStakingContract.sol");
  let {contractAddress} = await submitTransaction("0x" + contract.deploy({
    data: bytecode,
    arguments: [
      tokenAddress,
      randomSeed,
    ],
  }).encodeABI(), null, privateKey, web3);
  const abiFileName = contractFileName.substr(0, contractFileName.lastIndexOf(".")) + ".abi";
  const abiPath = `${distPath}/${abiFileName}`;
  mkdirp(distPath);
  fs.writeFileSync(abiPath, JSON.stringify(contract._jsonInterface));
  console.log(`Wrote ABI to ${abiPath}`)
  const stakingContract = new web3.eth.Contract(contract._jsonInterface, contractAddress)
  return contractAddress;
}

async function mintAndDepositTokens(stakingContractAddress) {
  const stakingAbi = JSON.parse(fs.readFileSync(stakingContractABIFilename));
  const stakingContract = new web3.eth.Contract(stakingAbi, stakingContractAddress)
  const tokenAbi = JSON.parse(fs.readFileSync(tokenContractABIFilename));
  const tokenContractAddress = await stakingContract.methods.token().call();
  const tokenContract = new web3.eth.Contract(tokenAbi, tokenContractAddress)

  blacksmithPrivateKeys.forEach(async (privateKey) => {
    let address = "0x" + util.privateToAddress(privateKey).toString("hex");
    await submitTransaction(tokenContract.methods.mint(address, amount).encodeABI(), tokenContractAddress, privateKey, web3);
    await submitTransaction(tokenContract.methods.approve(stakingContractAddress, amount).encodeABI(), tokenContractAddress, privateKey, web3);
    await tokenContract.methods.allowance(address, stakingContractAddress).call();
    let result = await submitTransaction(stakingContract.methods.deposit(amount).encodeABI(), stakingContractAddress, privateKey, web3);
    console.log(`Deposited ${amount / (10 **3)} tokens from ${address}`);
  });
}

async function deploy() {
    build();
    const tokenContractAddress = await deployToken();
    const stakingContractAddress = await deployStakingContract(tokenContractAddress);
    await mintAndDepositTokens(stakingContractAddress);
    console.log(`Token Contract Address: ${tokenContractAddress}`)
    console.log(`Staking Contract Address: ${stakingContractAddress}`)
}

switch (process.argv[2]) {
  case "build":
    build();
    break;
  case "deployToken":
    deployToken();
    break;
  case "deployStakingContract":
    deployStakingContract(process.argv[3]);
    break;
  case "mintAndDepositTokens":
    mintAndDepositTokens(process.argv[3]);
    break;
  default:
    deploy();
    break;
}
