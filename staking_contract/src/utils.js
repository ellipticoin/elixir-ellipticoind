import Promise from "bluebird";
import path from "path";
import fs from "fs";
import solcLinker from 'solc/linker';
import solc from "solc";
import _ from "lodash";
import BigNumber from "bignumber.js";
import Transaction from "ethereumjs-tx";
import util from "ethereumjs-util";
var Web3 = require('web3');
import { generatePrivateKey, createPrivateKey } from "ursa";

export const bytesToHex = (bytes) => `0x${bytes.toString("hex")}`;
export const hexToBytes = (hex) => new Buffer(hex.substring(2), "hex");

export const defaultContractOptions = {
  gasPrice: 100000000000,
  gasLimit: 10000000,
}
const {
  PRIVATE_KEY,
  WEB3_URL,
  BLACKSMITH_PRIVATE_KEYS,
} = process.env;
const blacksmithPrivateKeys = BLACKSMITH_PRIVATE_KEYS.split(",").map((privateKey) => Buffer.from(privateKey, "hex"));


export async function fundAndRegisterWithStakingContract(stakingAddress, amount) {
  var web3 = new Web3(WEB3_URL);
  const tokenFile = fs.readFileSync('./build/contracts/TestnetToken.json', "utf8");
  const stakingFile = fs.readFileSync('./build/contracts/EllipticoinStakingContract.json', "utf8");
  const tokenAbi = JSON.parse(tokenFile).abi;
  const stakingAbi = JSON.parse(stakingFile).abi;
  const stakingContract = new web3.eth.Contract(stakingAbi, stakingAddress);
  const tokenAddress = await stakingContract.methods.token().call();
  const tokenContract = new web3.eth.Contract(tokenAbi, tokenAddress);
  const privateKeysFile = fs.readFileSync('test/support/test_private_keys.txt', 'utf8');
  const privateKeys = privateKeysFile.trim().split("\n\n").map((pem) => createPrivateKey(pem));
  await Promise.map(blacksmithPrivateKeys, async (privateKey, index) => {
    let address = "0x" + util.privateToAddress(Buffer.from(privateKey, "hex")).toString("hex");
    await submitTransaction(tokenContract.methods.mint(address, amount).encodeABI(), tokenAddress, privateKey, web3);
    await submitTransaction(tokenContract.methods.approve(stakingAddress, amount).encodeABI(), tokenAddress, privateKey, web3);
    await submitTransaction(stakingContract.methods.deposit(amount).encodeABI(), stakingAddress, privateKey, web3);
    await submitTransaction(
      stakingContract.methods.setRSAPublicModulus(
        "0x" + privateKeys[index].getModulus().toString("hex")
      ).encodeABI(),
      stakingAddress,
      privateKey,
      web3
    );
  });
}


export function abiEncode(web3, parameters) {
  let parametersWithType = _.reduce(parameters, (result, value) => {
      let type;

      if(Number.isInteger(value)) {
        type = "uint256";
      } else {
        type = "address";
      }
      result[0].push(type);
      result[1].push(value.toString());

      return result;
    },
    [[],[]]);

  return web3.eth.abi.encodeParameters(...parametersWithType);
}

export async function deploy(web3, fileName, ...args) {
    let [contract, bytecode] = await compile(web3, fileName)
    args = args || [];
  // console.log(args);
    let deployed  = await contract.deploy({
        data: "0x00",
        arguments: [],
    }).send();

    return deployed;
}

export async function compile(web3, fileName) {
    let baseName = path.basename(fileName);
    let contractName = path.basename(fileName, ".sol");
    let contractsDir = path.resolve(__dirname, "..", "contracts");
    let content = fs.readFileSync(`/${contractsDir}/${fileName}`).toString();
    let sources = {
      [baseName]: {content}
    };
    var input = {
      language: 'Solidity',
      sources,
      settings: {
        outputSelection: {
          '*': {
            '*': [ '*' ]
          }
        }
      }
    }


    function findImports (dependencyPath) {
      let contractsPath  = path.resolve(process.cwd(), "contracts", dependencyPath)
      let npmPath  = path.resolve(process.cwd(), "node_modules", dependencyPath)
      if(fs.existsSync(contractsPath)) {
        return { contents: fs.readFileSync(contractsPath).toString() }
      } else if(fs.existsSync(npmPath)) {
        return { contents: fs.readFileSync(npmPath).toString() }
      } else {
        throw `${npmPath} not found in search path`;
      }
    }
    const output = solc.compile(JSON.stringify(input), findImports);

    if(JSON.parse(output).errors) {
      JSON.parse(output).errors.forEach(({formattedMessage}) => console.error(formattedMessage));
    };


    let bytecode = JSON.parse(output).contracts[baseName][contractName].evm.bytecode.object
    let linkReferences = JSON.parse(output).contracts[baseName][contractName].evm.bytecode.linkReferences
    for(let fileName in linkReferences){
      let baseName = path.basename(fileName);
      let contractName = path.basename(fileName, ".sol");
      let contractsDir = path.resolve(__dirname, "..", "contracts");
      let content = fs.readFileSync(`/${contractsDir}/${fileName}`).toString();
      let sources = {
        [baseName]: {content}
      };
      let libraryName = Object.keys(linkReferences[fileName])[0];
      var input = {
        language: 'Solidity',
        sources,
        settings: {
          outputSelection: {
            '*': {
              '*': [ '*' ]
            }
          }
        }
      }
      const output = solc.compile(JSON.stringify(input), findImports);
      let libraryBytecode = JSON.parse(output).contracts[baseName][contractName].evm.bytecode.object
      console.log({ [libraryName]: libraryBytecode })
      // bytecode = solcLinker.linkBytecode(bytecode, { [libraryName]: libraryBytecode })
    }
    console.log(bytecode);

    let abi = JSON.parse(output).contracts[baseName][contractName].abi;
    let accounts = await web3.eth.getAccounts();

    return [await (new web3.eth.Contract(abi, {
      ...defaultContractOptions,
      from: accounts[0],
    })), bytecode];
}

export function bytes64ToBytes32Array(signature) {
  return [
    bytesToHex(signature.slice(0, 32)),
    bytesToHex(signature.slice(32, 64)),
  ];
}

export function vmError(message) {
  return `VM Exception while processing transaction: ${message}`;
}

export async function assertFailure(assert, f, message) {
  try {
    await f();
  } catch (e) {
    return assert.equal(e.message, message);
  }
  assert.fail(null, null, `"${message}" never thrown`);
}

export async function mint(token, balances, accounts) {
  return await Promise.all(_.map(balances, async (value, account) =>
    token.mint(account, value))
  );
};

export function signatureToHex(signature) {
  return "0x" +
    signature[1].slice(2) +
    signature[2].slice(2) +
    _.padEnd(parseInt(signature[0]).toString(16), 2, "0");
}

export function signatureToBytes(signature) {
  return Buffer.from(
    signature[1].slice(2) +
    signature[2].slice(2) +
    _.padEnd(parseInt(signature[0]).toString(16), 2, "0"),
    "hex"
  );
}

export function hexToSignature(signature) {
  return [
    parseInt(signature.slice(130), 16) + 27,
    `0x${signature.slice(2, 66)}`,
    `0x${signature.slice(66, 130)}`,
  ];
}

export async function callLastSignature(contract) {
  return Buffer.concat([
    Buffer((await contract.lastSignature.call(0)).slice(2), "hex"),
    Buffer((await contract.lastSignature.call(1)).slice(2), "hex"),
  ]);
}

export async function registerPublicModuli(contract, accounts) {
  const contents = fs.readFileSync('test/support/test_private_keys.txt', 'utf8');
  const privateKeys = contents.trim().split("\n\n").map((pem) => createPrivateKey(pem));
  await Promise.all(accounts.map(async(account, i) =>{
      await contract.setRSAPublicModulus(
        privateKeys[i].getModulus(),
        {
          from: account
        },
  )}
  ));

  return _.zipObject(accounts, privateKeys);
}

export async function setup(token, contract, accounts) {
  await Promise.mapSeries(accounts, async([from, value]) => {
      await token.mint(from, value);
      await token.approve(contract.address, value, {
        from
      });
      return await contract.deposit(value, {from});
  });
}

export async function submitTransaction(data, to = null, privateKey, web3) {
  let address = "0x" + util.privateToAddress(privateKey).toString("hex");
  let nonce = web3.utils.toHex(await web3.eth.getTransactionCount(address));
  let tx;
  if (to) {
    tx = new Transaction({
      to,
      nonce,
      gasPrice: web3.utils.toHex(defaultContractOptions.gasPrice),
      gasLimit: web3.utils.toHex(defaultContractOptions.gasLimit),
      data,
    });
  } else {
    tx = new Transaction({
      nonce,
      gasPrice: web3.utils.toHex(defaultContractOptions.gasPrice),
      gasLimit: web3.utils.toHex(defaultContractOptions.gasLimit),
      data,
    });
  }
   tx.sign(privateKey);
   var serializedTx = tx.serialize();
   return await web3.eth
    .sendSignedTransaction("0x" + serializedTx.toString("hex"))
    // .then((address) => console.log(address));
}
