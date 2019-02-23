/*
 * The winner of each staking round is determined by the value of the signature chain. This value is dependant on the private key of the transaction it's sent from. It isn't possible to send transacations from a specific private key
 * without [building the transaction yourself](https://ethereum.stackexchange.com/a/25852) so we need to test against a determisitic set of private keys by running ganache with the following arugments:
 *
 * 
 * `ganache-cli -m "medal junk auction menu dice pony version coyote grief dream dinosaur obscure"`
 */
const TestToken = artifacts.require("./utils/TestToken.sol");
const Bridge = artifacts.require("./Bridge.sol");
const RSA = artifacts.require("utils/RSA.sol");
const EllipticoinStakingContract = artifacts.require("./EllipticoinStakingContract.sol");
const { generatePrivateKey } = require('ursa');
const Promise = require("bluebird");
const _ = require("lodash");
const chai = require("chai");
const chaiUseAsPromised = require("chai-as-promised");
chai.use(chaiUseAsPromised);
const assert = chai.assert;
const crypto = require("crypto");

const {
  abiEncode,
  bytes64ToBytes32Array,
  bytesToHex,
  callLastSignature,
  compile,
  defaultContractOptions,
  deploy,
  encodeSignature,
  expectThrow,
  hexToBytes,
  hexToSignature,
  mint,
  setup,
  signatureToBytes,
  signatureToHex,
  registerPublicModuli,
} = require("../src/utils.js");

const randomSeed = new Buffer(256);

contract("EllipticoinStakingContract", (accounts) => {
  let contract;
  let alice;
  let bob;
  let carol;
  let privateKeys;
  let token;
  let bridge;

  beforeEach(async () => {
    token = await TestToken.new();
    bridge = await Bridge.new();
    contract = await EllipticoinStakingContract.new(
      token.address,
      bridge.address,
      bytesToHex(randomSeed)
    );

    [alice, bob, carol] = accounts.slice(0, 3);
    privateKeys = await registerPublicModuli(contract, accounts.slice(0, 3));
  });

  describe("#submitBlock", () => {
    it("fails if the signature is incorrect", async () => {
      await setup(token, contract, [
          [alice, 100],
          [bob, 100],
          [carol, 100],
      ]);

      let blockNumber = 1;
      let blockHash = crypto.createHash('sha256').digest();
      let lastSignature = await contract.lastSignature.call();
      let invalidSignature = crypto.randomBytes(256);

      await assert.isRejected(
        contract.submitBlock(
          blockNumber,
          bytesToHex(blockHash),
          bytesToHex(invalidSignature), {
            from: bob,
          }),
        "revert",
      );
    });

    it("sets `lastestBlockHash` to the `blockHash` that was submitted", async () => {
      await setup(token, contract, [
        [alice, 1],
      ]);
      let blockNumber = 1;
      let blockHash = crypto.createHash('sha256').digest();
      let lastSignature = hexToBytes(await contract.lastSignature.call());
      const signature = privateKeys[alice].hashAndSign("sha256", lastSignature);

      await contract.submitBlock(
        blockNumber,
        bytesToHex(blockHash),
        bytesToHex(signature), {
          from: alice,
      });
      assert.equal(await contract.blockHash.call(), bytesToHex(blockHash));
    });

    it("sets `lastSignature` to the `signature` that was submitted", async () => {
      await setup(token, contract, [
        [alice, 1],
      ]);
      let blockNumber = 1;
      let blockHash = crypto.createHash('sha256').digest();
      let lastSignature = hexToBytes(await contract.lastSignature.call());
      const signature = privateKeys[alice].hashAndSign("sha256", lastSignature);
      await contract.submitBlock(
        blockNumber,
        bytesToHex(blockHash),
        bytesToHex(signature), {
          from: alice,
      });
      assert.equal(await contract.lastSignature.call(), bytesToHex(signature));
    });
  });

  describe("#winner", () => {
    it("returns a random winner each staking round", async () => {
      await setup(token, contract, [
          [alice, 100],
          [bob, 100],
          [carol, 100],
      ]);
        let winners = await Promise.mapSeries(_.times(3), async (n) => {
          let blockNumber = 1;
          let blockHash = crypto.createHash('sha256').digest();
          let winner = await contract.winner.call();
          let lastSignature = hexToBytes(await contract.lastSignature.call());
          let signature = privateKeys[winner].hashAndSign("sha256", lastSignature);
          await contract.submitBlock(
            blockNumber,
            bytesToHex(blockHash),
            bytesToHex(signature), {
              from: winner,
          });

          return winner;
        });
        assert.deepEqual(winners, [alice, carol, bob]);
    });
  });
});
