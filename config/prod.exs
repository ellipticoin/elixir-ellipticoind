use Mix.Config

config :ellipticoind, base_contracts_path: "./base_contracts"
config :ellipticoind, port: String.to_integer(System.get_env("PORT") || "4045")

config :ellipticoind,
  staking_contract_address:
    (System.get_env("STAKING_CONTRACT_ADDRESS") || "") |> Base.decode16!(case: :mixed)

config :ellipticoind, P2P.Transport.Noise,
  private_key:
    "FbJ84KTznL4ME5InsxJalt5Asv5tVTRJwGnkZTMXMLe9Ayfcm9LcBMhO15D6A5h+5VKfZu64Af7h7w1j8K+3AA=="
    |> Base.decode64!(),
  port: if(System.get_env("PORT"), do: System.get_env("PORT") |> String.to_integer(), else: 4047),
  bootnodes:
    File.read!("./priv/bootnodes.txt")
    |> String.split("\n", trim: true)

config :ellipticoind, Ellipticoind.Repo,
  username: System.get_env("DATABASE_USER"),
  password: System.get_env("DATABASE_PASS"),
  database: System.get_env("DATABASE_NAME") || "ellipticoin",
  hostname: System.get_env("DATABASE_HOST"),
  pool_size: 15
