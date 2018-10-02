const FakeBlockchain = require("./support/fake-blockchain");
const assert = require("assert");
const _ = require("lodash");
const UNKNOWN_ADDRESS = Buffer.from("0000000000000000000000000000000000000000", "hex");
const SENDER = Buffer.from("0000000000000000000000000000000000000001", "hex");
const RECEIVER = Buffer.from("0000000000000000000000000000000000000002", "hex");
const PRIVATE_KEY = "421b15261849f1b6aa6fc5b0758f7da22b31e74bed1e4a01dfac7bb8f931a4f";
const PUBLIC_KEY = "04b0dc9c483f4aaefcc62adec054f14ee2230c8d11fed03a89f6ebe8c9f20475fdd96be3d53108d2cebcc183e4c08f5f074bbc48f8fc928dcd0926b81e5113b35b";
const randomSeed = Buffer.alloc(32);
const ERROR_INSUFFICIENT_FUNDS = 1;
const ERROR_CODES = {
  INSUFFIENT_FUNDS: 1,
};
const {
  sha3,
  genKeyPair,
  sign,
} = require("./support/utils");

describe("LeaderElection", function() {
  var blockchain;

  beforeEach(async () => {
    blockchain = new FakeBlockchain({
      defaultSender: SENDER,
    });

    await blockchain.loadFile("./dist/adder.wasm");
  });

  afterEach(() => blockchain.reset());

  describe("adder", function() {
    it("should add numbers", async function() {
      console.log(blockchain.instance.exports)
      let sum = await blockchain.call("add", 1, 2);

      assert.equal(sum, 3);
    });
  });
});
