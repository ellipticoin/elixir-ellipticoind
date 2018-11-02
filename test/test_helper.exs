Application.ensure_all_started(:cowboy, :ranch)
ExUnit.start()
HTTPoison.start()
Ecto.Adapters.SQL.Sandbox.mode(Blacksmith.Repo, :manual)
