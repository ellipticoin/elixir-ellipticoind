Elipticoin
==========

Elipticoin is a Ethereum-like blockchain that's optimized for transaction
throughput. It uses  [proof of
stake](https://en.wikipedia.org/wiki/Proof-of-stake)  as a consensus algorithm which doesn't
burn excessive energy like proof of work does.

## Differences From Ethereum

Elipticoin takes a lot of ideas from Ethereum and wouldn't have existed if it
weren't for Ethereum though Elipticoin has different goals and intentions than
Ethereum.

First, the Elipticoin consensus algorithm will be proof of stake from the
start. This is important because of the mass amount of energy that's being
burned every day that Ethereum is still running proof of work. The Ethereum team
is planning to switch to a full proof of stake protcol as well in the near
future.

Second, the Elipticoin network doesn't aim for perfect decentralization. If
running a staking node costs $1000 an month that would be considered acceptable.
Elipticoin also doesn't use Merkle trees for storing state so lite clients won't
be possible. Making these trade-offs allows many more transactions to be
processed in each block. Note that making a transaction on the network does not
require running a staking node. It's the hope that public nodes are set up such
as the [infura public nodes](https://infura.io/) which will give anyone
uncensored access to the network. It's also possible that the network splits
into a faster network run by more powerful stakers and a slower one that's more
decentralized.

It's our hope that multiple blockchains will foster competition
and innovation in the space. If blockchains are built to be interoperable users
can switch between them and use the one that best fits their needs.


## Use of existing technologies

Elipticoin is deliberately built with existing open source components when
possible. This cuts down on the surface area of the codebase and leverages the
the work of existing projects.

  * [Libp2p and Floodsub](https://github.com/libp2p/go-floodsub) for peer to peer communication
  * [Protobufs](https://github.com/google/protobuf) for encoding data
  * [Wagon WebAssembly Interpreter](https://github.com/go-interpreter/wagon) as a virtual machine
  * [Lua](https://github.com/vvanders/wasm_lua) as a programming language (any language
that targets the llvm should work as well)

## Differences From Cardano

Cardano and the Ouroboros protocol are a gift to the blockchain
community. Elipticoin will base a lot of the protcol on the concepts in the Ouroboros white paper with the following differences:

### Leader Election

 In Proof of Work the miner who mines block with the most leading zeros gets to
 mine the block and be the leader of that round of consensus. If you want to
construct a similar protocol in Proof of Stake you need some source of
randomness to randomly select a leader each round. Cardando uses a multiparty
coin-flipping protocol as a source of randomness. Elipticoin uses a random seed
and a signature chain as it's source of randomness. The slot leader of block 1
is determined by some [random seed
value](https://en.wikipedia.org/wiki/Random_seed). This could be any random
value but elipticoin will base it off of the combination of 2 agreed upon block
hashes at certain heights in the Bitcoin and Ethereum blockchains. The slot
leader of block 1 would then sign this value with their private key. The leader
of block 2 block is determined by the value of the signature. The leader of
block 2 then signs this resulting value and so on. This eliminates any sort of
"grinding" attacks outlined in the Cardano white paper because there's nothing
to grind. Signers don't have any control over the value of their signature.
This eliminates the complexity in both the commitment and reveal phase of
randomness and computing a random number from those values.

### Incentives and Disincentives

Elipticoin will be much more draconian than Cardano. Any staker provably
violating any rule in the network will loose all of their stake. If a staker is
elected as a slot leader and fails to publish a block in the 3 second time
period they will loose their entire stake as well. The protocol is not designed
to serve the stakers it's designed to serve the users. Staking will be a risky endeavor
and should only be done by those willing to take those risks.

### Stake Delegation and Pooling

Stake delagation won't be built into the protocol like it is in Cardano.
Staking pools can be built as smart contracts and run on the Elipticoin network.
This simplifies the protocol.

The Protocol
============


Message Types
-----

create
* from
* code
* maxPrice
* nonce
* signature

transaction
* from
* to
* amount
* maxPrice
* nonce
* signature

call
 * from
 * contractAddress
 * method
 * [arg1, arg2…]
 * maxPrice
 * nonce
 * signature

### The Block Hash
Messages are ordered creates first, transactions, then calls and then by the
order of fields above. They are encoded with as a [ProtoBuf](https://github.com/google/protobuf) and then a SHA3 is
taken of the resulting binary. That give us the blockhash.


The mining block reward is all the transaction fees + all burned value + the distribution amount.

21 million coins will be issued over a 5 year period.

Blocks are mined every 3 seconds.

Distribution amount is a constant:

21,000,000/ 31557600 seconds in a year / 3 * 5  years = 0.39926990645 coins per block)

Burning coins 7 days in advance and punishing misbehavior alleviates the “nothing at stake” problem.
If the chain forks the attacker has already burned their coins.

Gas costs:

  * transaction: 1 create: 1 * byte size
  * call: 10 + IO costs

IO costs:

  * read: 1
  * write: 2
  * allocate: 1
  * destroy: -1

Transaction processing is for the most part IO bound not processor bound:
https://www.youtube.com/watch?v=naPA7tjrgsk&feature=youtu.be&t=31m30s

Miners will decide if a transaction takes too long to run.
Initially it's suggested to reject any transaction that takes longer that 100ms
to run and reject blocks from other miners that contain transactions that take
longer that 1 second to run. If CPU run time becomes an issue we can inject gas
metering as implemented [here](https://github.com/ewasm/wasm-metering).

Eliminating gas cost calculation for each assembly operation vastly simplifies
the protocol. It also removes the gas metering step.




An Example Token contract in Lua
-------------------------------


    function on.initialize()
      storage.store(blockchain.sender, 100)
    end

    function get_balance(address)
      if storage.load(address) == nil then
        return 0
      else
        return storage.load(address)
      end
    end

    function transfer(amount, address)
      balance = get_balance(blockchain.sender)

      if amount <= balance then
        storage.store(blockchain.sender, balance - amount)
        storage.store(address, get_balance(address) + amount))
      else
        control.throw("not enough funds")
      end
    end


