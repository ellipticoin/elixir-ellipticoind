use Mix.Config

config :ellipticoind,
  private_key:
    "0dEZGu7DxJ1E9+HWKoW7fi8UhgUgerMO+P8HSAFoexhTkx5G5592nOxcyySxB1SCEPOAiVmGbYQbr0dK0S1wBg=="
    |> Base.decode64!()
