const WasmRPC = require("wasm-rpc").default;
const assert = require("assert");

describe("Adder", function() {
  var adder;

  beforeEach(async () => {
    adder = new WasmRPC({
      "exports": {
        "__log_write": () => null,
      }
    });

    await adder.loadFile("./target/wasm32-unknown-unknown/debug/adder.wasm");
  });

  describe("adder", function() {
    it("should add numbers", async function() {
      let sum = await adder.call("add", 1, 2);

      assert.equal(sum, 3);
    });
  });
});
