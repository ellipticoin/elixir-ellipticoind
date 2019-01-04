const bytesToHex = (bytes) => `0x${bytes.toString("hex")}`;
var fs = require('fs');
var Web3 = require('web3');
var web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));
var abi = JSON.parse(fs.readFileSync("staking_contract/dist/EllipticoinStakingContract.abi", "utf-8"));
var tokenAbi = JSON.parse(fs.readFileSync("staking_contract/dist/TestnetToken.abi", "utf-8"));
var publicModulus = Buffer.from("C932434D8A2F77798923A6CB3BBC13A26719D98020294EA3E7FF946C2B752F419BE9E8FB3C007FC8B34F3E9AF4400617064DC16F2DFB1D693645DE3BC0F8AFB604B610FE4B97527E194D87B9882CEC75895F5304BFEB603A3FCFF6F40C685C7A48FA6E926F5ADA5D3A2E215F0C56E96BD032A469D7327D183E8A609DCBA550079EEE5C884A9D51B67C98673431FF7B71AD7245DD21B113B1952515548EF73CF375A93FC0264020A09D2C488010AEFC2E288B4AC535434BB10363FAC944970EFC619DC67EA8DBCF97BBDC745C6FC39A0476D04587F7A831C383D6CFF13507FB0A53ECD72533066771339C92F16526763A17B87DB21BACD6AA43A34D6C739D3435", "hex")
var address = "0x3b7A9659627F64488251d5bC750ba4218f6fff41";
var tokenAddress = "0x7559aDa1E3F2E41DaF8f367a7bf15adEE611380C";
var from = "0x9220f96a2a055af051b699087f47baa59325df0c";
var contract = new web3.eth.Contract(abi, address, {"from": "0x9220f96a2a055af051b699087f47baa59325df0c"});
var testnetToken = new web3.eth.Contract(tokenAbi, tokenAddress, {"from": "0x9220f96a2a055af051b699087f47baa59325df0c"});
// contract.methods.totalStake().call().then(console.log);
contract.methods.token().call().then((address) =>{
  // console.log(`Set token address to: ${address}`)
})
const run = async () => {
  // console.log(Buffer.byteLength(publicModulus))
  let nonce = await web3.eth.getTransactionCount(from);
  let data = contract.methods.setRSAPublicModulus(bytesToHex(publicModulus)).encodeABI()
  console.log(data)
  let signedTx = await web3.eth.accounts.signTransaction({
    to: address,
    data,
    value: 0,
    nonce: nonce,
    gas: 3000000,
    gasPrice: 1000000000,

  }, "0x43622b10a1d41a3ba7b7ce4f26bffca0193c0f1c5ff497b04760e940fceff15d");
  // await web3.eth.sendSignedTransaction(signedTx.rawTransaction)
  // console.log( await contract.methods.getRSAPublicModulus("0x9220f96a2a055af051b699087f47baa59325df0c").call());
};
run();

  // contract.methods.setRSAPublicModulus(bytesToHex(publicModulus)).send({from: "0x9220f96a2a055af051b699087f47baa59325df0c", gas: 3000000})
  //   .then(() => {
  //   contract.methods.getRSAPublicModulus("0x9220f96a2a055af051b699087f47baa59325df0c").call().then((publicModulus) =>{
  //     console.log(`publicModulus: ${publicModulus}`)
  //   })
  // })
    
  //   .then((address) =>{
  //   console.log(`Set token address to: ${address}`)
  // })
  // testnetToken.methods.mint("0xb0c3d6bfce766424aa0373458affab6e7904b277", 100).send().then(() => {
  //   testnetToken.methods.totalSupply().call().then(console.log)
  // });
  // console.log("minting")
