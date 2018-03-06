defmodule Blacksmith do
  use Application

  def start(_type, _args) do
    Blacksmith.Supervisor.start_link(name: Blacksmith.Supervisor)
  end
end
