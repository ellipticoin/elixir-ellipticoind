use Mix.Config

config :blacksmith,
  private_key: Base.decode16!("8f515a41d467d7547cbab2eec3948250a4d1ba4f23881ce350cc72fb4a77efff", case: :lower)
