use Mix.Config

config :blacksmith,
  ethereum_private_key:
    Base.decode16!("8f515a41d467d7547cbab2eec3948250a4d1ba4f23881ce350cc72fb4a77efff",
      case: :lower
    )
config :blacksmith,
  alices_ethereum_private_key:
    Base.decode16!("8f515a41d467d7547cbab2eec3948250a4d1ba4f23881ce350cc72fb4a77efff",
      case: :lower
    )
config :blacksmith,
  bobs_ethereum_private_key:
    Base.decode16!("cd795250078342a7881a69261b9ec96536cbc12e14a3f67d7c578f83c3df5d38",
      case: :lower
    )
