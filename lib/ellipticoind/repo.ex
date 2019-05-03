defmodule Ellipticoind.Repo do
  use Ecto.Repo,
    otp_app: :ellipticoind,
    adapter: Ecto.Adapters.Postgres
end
