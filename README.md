Ellipticoind
==========

Ellipticoind is the reference implementation of an Ellipticoin node written in
Elixir.

Running Ellipticoind:
==========================

From a binary release
-----

Installation instructions for Ubuntu 18.0.4 (Bionic Beaver)

0. Ensure you’re running version 18.0.4 of Ubuntu. If you’re running on a different version of Ubuntu or a different operating system you’ll have to build from source for now.

1. Install the required dependencies:

    `$ apt-get update && apt-get install postgresql redis-server`

2. Create a postgres user:

    `$ su -c "createuser ellipticoin" postgres`

3. Create a postgres db:

    `$ su -c "createdb ellipticoin" postgres`


4. Create a user that will run the ellipticoind:

    `$ adduser --disabled-password  --gecos "Ellipticoin" ellipticoin`

5. Execute the remaining commands as the ellipticoin user:

    `su ellipticoin`

6. Change the working directory to the home folder of the user you just created:

    `$ cd /home/ellipticoin`

7. Download the latest release:

    `wget https://github.com/ellipticoin/ellipticoin-node/releases/download/0.1.0-alpha/ellipticoind-ubuntu-18-04-0.1.0.tar.gz`

8. Extract it:

    `$ tar -xf ellipticoind-ubuntu-18-04-0.1.0.tar.gz`


9. Migrate the database:

    `$ ./bin/node migrate`

10. Generate a private key for your node:

    ```
    $ ./bin/node generate_private_key
    New private_key:
    LZf9CkbgnZzBKQWfd9ywu9B8XF+wZbRzulAr3ZLogWPIKAJesHzDBDTHJ2foOB/gjLcqLQyfYu8ORK97G05zPg==
    ```

11. Update your private key in `etc/config.exs`.


12. Run the server in the foreground to make sure everything is set up correctly:

    `$ ./bin/node foreground`

13. Start the server in the background:

    `$ ./bin/node start`

From Source
-----
1. Clone the repo:  `git clone https://github.com/ellipticoin/ellipticoin-node && cd ellipticoin-blacksmith-node`
2. Update `ETHEREUM_PRIVATE_KEY` and anything else you'd like to customize in
   `config/dev.secret.exs` and `config/dev.exs`
3. Run: `mix dep.get`
4. Run: `mix run --no-halt`
