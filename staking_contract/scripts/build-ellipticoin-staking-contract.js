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
const tokenAddress = "0xA1FB77a212419bfE1B58E906DC39993823b424EC";
const randomSeed = web3.utils.randomHex(32);
const privateKey = new Buffer(process.env.PRIVATE_KEY, "hex");
const contractFileName = "EllipticoinStakingContract.sol";
const distPath = "./dist";

let address = "0x" + util.privateToAddress(privateKey).toString("hex");

 async function run() {
  let [contract, bytecode] = await compile(web3, contractFileName);
  const bytecodeBytes = Buffer.from(bytecode, "hex");
  const bytecodeFileName = contractFileName.substr(0, contractFileName.lastIndexOf(".")) + ".hex";
  const abiFileName = contractFileName.substr(0, contractFileName.lastIndexOf(".")) + ".abi";

  fs.writeFileSync(`${distPath}/${bytecodeFileName}`, bytecode);
  console.log(`Wrote ${distPath}/${bytecodeFileName}`)
  fs.writeFileSync(`${distPath}/${abiFileName}`, JSON.stringify(contract._jsonInterface));
  console.log(`Wrote ${distPath}/${abiFileName}`)
}

run();
