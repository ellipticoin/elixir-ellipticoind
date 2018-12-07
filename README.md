Ellipticoin Blacksmith Node
==========

Ellipticoin is a developer friendly scalable Ethereum side-chain. Blacksmith
nodes forge transactions to keep the network secure. They are authenticated via [proof
of
burn](https://www.masonforest.com/blockchain/ethereum/ellipticoin/2018/05/29/the-ellipticoin-proof-of-burn-algorithm.html)
which has similar economic incentives to proof of work except instead of
burning energy they burn tokens on the parent chain.

You can install the [reference wallet](https://www.npmjs.com/package/ec-wallet) to use the Ellipticoin network itself.


Running a Blacksmith Node:
==========================

Using docker-compose
-----
1. Clone the repo:  `git clone https://github.com/ellipticoin/ellipticoin-blacksmith-node && cd ellipticoin-blacksmith-node`
2. Install Docker
2. Update `ETHEREUM_PRIVATE_KEY` in `config/docker.env`
3. Run `docker-compose up`

From a binary release
-----

1. Create an `Ubuntu 18.04` VPS/Droplet (or another type of VPS and create a
   PR!)
2. Download the appropriate release for your system and extract it:
````
$ cd /usr/local
$ wget blacksmith.tar.gz
$ tar -xf blacksmith.tar.gz
$ rm blacksmith.tar.gz
````
3. Run `sh ./releases/0.1.0/commands/install_deps.sh` to install the required dependencies.
4. Allow all postgres connections from localhost:

Edit: /etc/postgresql/10/main/pg_hba.conf

    Change the line:
````
local   all             postgres                                peer
````
to
````
local   all             postgres                                trust
````
5. Restart postgres: `sudo service postgresql restart`

6. Create the blacksmith's db: `createdb -U postgres blacksmith`
7. Update `ETHEREUM_PRIVATE_KEY` and anything else you'd like to customize in
   `/usr/local/etc/config.exs`

9. Run the blacksmith node in the forground to check if everything is set up correctly: `blacksmith foreground`

10. If everything looks to be working you can kill the node and start it again in the background: `blacksmith start`

From Source
-----
1. Clone the repo:  `git clone https://github.com/ellipticoin/ellipticoin-blacksmith-node && cd ellipticoin-blacksmith-node`
2. Update `ETHEREUM_PRIVATE_KEY` and anything else you'd like to customize in
   `config/dev.secret.exs` and `config/dev.exs`
3. Run: `mix dep.get`
4. Run: `mix run --no-halt`
