require('@babel/register');
require('dotenv').config()
const HDWalletProvider = require("truffle-hdwallet-provider");

const {
  PRIVATE_KEY,
  WEB3_URL
} = process.env;

var rinkebyProvider = new HDWalletProvider(PRIVATE_KEY, WEB3_URL);
module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*" // Match any network id
    },
    rinkeby: {
      provider: rinkebyProvider,
      network_id: 4
    },
  },
};
