defmodule Blacksmith.Repo do
  use Ecto.Repo,
    otp_app: :blacksmith,
    adapter: Ecto.Adapters.Postgres
end
