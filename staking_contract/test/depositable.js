const TestToken = artifacts.require("./test/TestToken.sol");
const Depositable = artifacts.require("./utils/Depositable.sol");

contract("Depositable", (accounts) => {
  let contract;
  let alice;
  let bob;
  let token;

  beforeEach(async () => {
    token = await TestToken.new();
    contract = await Depositable.new(
      token.address,
    );
    [alice, bob] = await web3.eth.getAccounts();
  });

  describe("#deposit", () => {
    it("increases the user's balance", async () => {
      token.mint(alice, 2, {
        from: alice
      });

      await token.approve(contract.address, 2, {
        from: alice
      });
      await contract.deposit(2, {
        from: alice,
      });

      assert.equal(await contract.balanceOf.call(alice), 2);
    });
  });

  describe("#withdraw", () => {
    it("decreases the user's balance", async () => {
      await token.mint(alice, 5);

      await token.approve(contract.address, 5, {
        from: alice
      });
      await contract.deposit(5, {
        from: alice,
      });
      await contract.withdraw(2, {
        from: alice,
      });

      assert.equal(await contract.balanceOf.call(alice), 3);
      assert.equal(await token.balanceOf.call(alice),  2);
    });

    it("removes the user if their balance is 0", async () => {
      token.mint(alice, 5);

      await token.approve(contract.address, 5, {
        from: alice
      });
      await contract.deposit(5, {
        from: alice,
      });
      await contract.withdraw(5, {
        from: alice,
      });

      assert.equal(await contract.addressesLength.call(), 0);
    });
  });

  describe("#totalStake", () => {
    it("sums the deposits", async () => {
      token.mint(alice, 3);

      token.mint(bob, 2, {
        from: alice
      });

      await token.approve(contract.address, 3, {
        from: alice
      });
      await contract.deposit(3, {
        from: alice,
      });
      await token.approve(contract.address, 2, {
        from: bob
      });
      await contract.deposit(2, {
        from: bob,
      });

      assert.equal(await contract.totalStake.call(), 5);
    });
  });
});
