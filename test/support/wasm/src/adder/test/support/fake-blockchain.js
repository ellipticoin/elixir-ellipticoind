const WasmRPC = require('/Users/masonf/src/js-wasm-rpc-client').default;
const { execFileSync } = require('child_process');
const cbor = require('cbor');
const { StringDecoder } = require('string_decoder');
const {
  recoverPublicKey
} = require('./utils');

class FakeBlockchain extends WasmRPC {
  constructor(params) {
    super({
      exports: {
      rust_begin_unwind: () => null,
      _sender: () => {
        return this.writePointer(params.defaultSender);
      },
      _block_winner: () => {
        return this.writePointer(params.defaultSender);
      },
      _secp256k1_recover: (messagePtr, signaturePtr, recoveryId) => {
        let message = this.readPointer(messagePtr);
        let signature = this.readPointer(signaturePtr);
        let publicKey = recoverPublicKey(message, signature, recoveryId);

        return this.writePointer(publicKey);
      },
      rust_oom: () => null,
      _read: (keyPtr) => {
        const decoder = new StringDecoder('utf8');
        var key = decoder.write(Buffer.from(this.readPointer(keyPtr)));
        if(this.storage[key]) {
          return this.writePointer(this.storage[key]);
        } else {
          return this.writePointer(new Uint8Array([]));
        }
      },
      _write: (keyPtr, valuePtr) => {
        const decoder = new StringDecoder('utf8');
        var key = decoder.write(Buffer.from(this.readPointer(keyPtr)));
        var value = this.readPointer(valuePtr);

        this.storage[key] = value;
      },
      throw: console.log,
        __udivti3: () => null,
        __multi3: () => null,
        _call: (codePtr, methodPtr, paramsPtr, storageContextPtr) => {
          const decoder = new StringDecoder('utf8');
          var code = this.readPointer(codePtr);
          var method = decoder.write(Buffer.alloc(this.readPointer(methodPtr)));
          var params = cbor.decode(Buffer.alloc(this.readPointer(paramsPtr)));
          var storageContext = this.readPointer(storageContextPtr);
          return this.writePointer(this._call(code, method, params, storageContext));
        },
      }
    })

    this.storage = this.storage || {};
  }

  reset() {
    this.storage = {};
  }
  readStorage(key) {
    return this.storage[key];
  }
  _call(code, method, params, storageContext) {
    var runWasmCode = `
      const cbor = require('cbor');
      const WasmRPC = require('/Users/masonf/src/wasm-rpc');
      const code = Buffer.from("${Buffer.from(code).toString("hex")}", "hex");
      const storageContext = Buffer.alloc("${Buffer.alloc(storageContext).toString("hex")}", "hex");
      const params = cbor.decode(Buffer.from("${Buffer.alloc(cbor.encode(params).toString("hex"))}", "hex"));
      const method = "${method}";
      function hexToBytes(hex) {
          for (var bytes = [], c = 0; c < hex.length; c += 2)
          bytes.push(parseInt(hex.substr(c, 2), 16));
          return Buffer.from(bytes);
      }

      async function run() {
        const wasm = new WasmRPC({
          exports: {
            sender: () => {
              return wasm.writePointer(hexToBytes("0000000000000000000000000000000000000001"));
            },
            read: (keyPtr) => {
              this.storage = this.storage || {};
              var key = wasm.readPointer(keyPtr);
              if(this.storage[key]) {
                return wasm.writePointer(this.storage[key]);
              } else {
                return wasm.writePointer(new Uint8Array([]));
              }
            },
            write: (keyPtr, valuePtr) => {
              var key = wasm.readPointer(keyPtr);
              var value = wasm.readPointer(valuePtr);

              this.storage = this.storage || {};
              this.storage[key] = value;
            },
            _call: () => null,
            rust_begin_unwind: () => null,
          }
        });
        await wasm.load(code);
        const result = wasm.call(method, ...params);
        process.stdout.write(Buffer.concat([
          Buffer.alloc([0,0,0,0]),
          Buffer.alloc(cbor.encode(result)),
        ]));
      };
      run();`;

    return execFileSync('ellipticoind', ['-e', runWasmCode]);
  }
}

module.exports = FakeBlockchain;
