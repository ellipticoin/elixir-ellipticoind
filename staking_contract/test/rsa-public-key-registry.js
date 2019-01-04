require('@babel/register');
const { generatePrivateKey } = require('ursa');
// import web3 from "./web3";
// import 'babel-polyfill';
const chai = require("chai");
const chaiUseAsPromised = require("chai-as-promised");
chai.use(chaiUseAsPromised);
const assert = chai.assert;
//
const {
  deploy,
  bytesToHex,
} = require("../src/utils");
// import _ from "lodash";
//
var RSA = artifacts.require("utils/RSA.sol");
var RSAPublicModuliRegistry = artifacts.require("./RSAPublicModuliRegistry.sol");

contract('RSAPublicModuliRegistry', function(accounts) {
  let contract;
  let alice;
  let bob;
  let token;

  beforeEach(async () => {
    await RSA.deployed();
    contract = await RSAPublicModuliRegistry.new();
    await RSAPublicModuliRegistry.deployed();
    [alice, bob] = accounts;
  });

  describe("#setRSAPublicModulus", () => {
    it("only allows the public modulus to be set once", async () => {
      let privateKey = generatePrivateKey();
      let publicModulus = privateKey.getModulus();

      await contract.setRSAPublicModulus(
        bytesToHex(publicModulus)
      );
      await assert.isRejected(
        contract.setRSAPublicModulus.call(
          bytesToHex(publicModulus)
        ),
          "revert",
        );
    });

    it("fails if the public modulus isn't 256 bytes", async () => {
      let privateKey = generatePrivateKey();
      let publicModulus = privateKey.getModulus();

      await assert.isRejected(
        contract.setRSAPublicModulus(
          publicModulus.slice(0, 255)
        ),
          "revert",
        );
    });

    it("sets the user's RSA public modulus", async () => {
      let privateKey = generatePrivateKey(2048);
      let publicModulus = privateKey.getModulus();

      let result = await contract.setRSAPublicModulus(
      bytesToHex(publicModulus),
        {
          from: alice,
        }
      );

      assert.equal(await contract.getRSAPublicModulus.call(alice), bytesToHex(publicModulus));
    });
  });
});
