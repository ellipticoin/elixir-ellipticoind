require("@babel/register");
require('dotenv').config();
const {
  compile,
  submitTransaction,
} = require("../src/utils");
const Web3 = require("web3");
const fs = require("fs");
const mkdirp = require('mkdirp');
const util = require("ethereumjs-util");
const Transaction = require('ethereumjs-tx');
const path = require('path');
const web3 = new Web3(process.env.WEB3_URL);
const contractPath = "utils/TestnetToken.sol";
const contractFileName = "utils/TestnetToken.sol";
const distPath = "./dist";
const tokenName = "[testnet] DAI Token";
const tokenSymbol = "DAI"
const tokenDecimals = 3;
const tokenSupply = 100 * (10 ** tokenDecimals);
const privateKey = new Buffer(process.env.PRIVATE_KEY, "hex");
let address = "0x" + util.privateToAddress(privateKey).toString("hex");

 async function run() {
  let [contract, bytecode] = await compile(web3, contractPath);
  let {contractAddress} = await submitTransaction("0x" + contract.deploy({
      data: bytecode,
      arguments: [tokenName, tokenSymbol, tokenDecimals],
  }).encodeABI(), null, privateKey, web3);
  console.log(`Token Address: ${contractAddress}`)
  contract.options.address = contractAddress;
  let {transactionHash}  = await submitTransaction(contract.methods.mint(address, tokenSupply).encodeABI(), contractAddress, privateKey, web3);
  console.log(`Minted: ${tokenSupply/(10 ** tokenDecimals)} ${tokenSymbol}`);
  console.log(`Transaction Hash: ${transactionHash}`);
  const contractFileName = path.parse(contractPath).base;
  const abiFileName = (contractFileName).substr(0, contractFileName.lastIndexOf(".")) + ".abi";
  const abiPath = `${distPath}/${abiFileName}`;
  mkdirp(distPath);
  fs.writeFileSync(abiPath, JSON.stringify(contract._jsonInterface));
  console.log(`Wrote ABI to ${abiPath}`)
}
 run();
