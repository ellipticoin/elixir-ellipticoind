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
const tokenAddress = "0xF8CADdFC462a7e211e95dbA22bdD8a40eE77EFe5";
const randomSeed = web3.utils.randomHex(32);
const privateKey = new Buffer(process.env.PRIVATE_KEY, "hex");
const contractFileName = "EllipticoinStakingContract.sol";
const distPath = "./dist";

let address = "0x" + util.privateToAddress(privateKey).toString("hex");

 async function run() {
  let [contract, bytecode] = await compile(web3, "EllipitcoinStakingContract.sol");
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
   console.log(`Contract Address: ${contractAddress}`)
   console.log(`Wrote ABI to ${abiPath}`)
   const stakingContract = new web3.eth.Contract(contract._jsonInterface, contractAddress)
}
 run();
