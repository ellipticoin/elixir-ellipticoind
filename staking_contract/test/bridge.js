const TestToken = artifacts.require("./test/TestToken.sol");
const Bridge = artifacts.require("./utils/Bridge.sol");
const {
  bytesToHex,
} = require("../src/utils.js");

contract("Bridge", (accounts) => {
  let contract;
  let alice;
  let bob;
  let token;

  beforeEach(async () => {
    token = await TestToken.new();
    contract = await Bridge.new(
      token.address,
    );
    [alice, bob] = await web3.eth.getAccounts();
  });

  describe("#mint", () => {
    it("appends to the list of minted coins", async () => {
      let alicesEllipticoinAddress = Buffer(32);
      token.mint(alice, 2, {
        from: alice
      });

      await token.approve(contract.address, 2, {
        from: alice
      });

      await contract.mint(token.address, bytesToHex(alicesEllipticoinAddress), 2, {
        from: alice,
      });

      let blockNumber = await web3.eth.getBlockNumber();
      let mintedBlocksLength = await contract.mintedCoinLengths(blockNumber);
      let mintedBlocks = await Promise.all(_.range(mintedBlocksLength)
        .map(async (index) => [
            await contract.mintedCoinTokenAddresses(blockNumber, index),
            await contract.mintedCoinRecipientAddresses(blockNumber, index),
            await contract.mintedCoinValues(blockNumber, index),
        ]
        ))

      assert.deepEqual(mintedBlocks, [[
        token.address,
        bytesToHex(alicesEllipticoinAddress),
        web3.utils.toBN(2),
      ]])
    });

    it("transfers the tokens to the bridge", async () => {
      let alicesEllipticoinAddress = Buffer(32);
      token.mint(alice, 2, {
        from: alice
      });

      await token.approve(contract.address, 2, {
        from: alice
      });

      await contract.mint(token.address, bytesToHex(alicesEllipticoinAddress), 2, {
        from: alice,
      });

      assert.equal(await token.balanceOf(alice), 0);
      assert.equal(await token.balanceOf(contract.address), 2);
    });
  });
});
