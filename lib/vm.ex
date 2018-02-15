defmodule VM do
  use Rustler, otp_app: :blacksmith, crate: :vm

  def run(_db, _code, _func, _arg), do: exit(:nif_not_loaded)
  def open_db(_arg1), do: exit(:nif_not_loaded)
end
