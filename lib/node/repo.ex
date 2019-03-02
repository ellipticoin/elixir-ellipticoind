defmodule Node.Repo do
  use Ecto.Repo,
    otp_app: :node,
    adapter: Ecto.Adapters.Postgres
end
