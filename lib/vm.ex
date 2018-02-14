defmodule VM do
  use Rustler, otp_app: :blacksmith, crate: :vm

  def run(_arg1, _arg2, _arg3), do: exit(:nif_not_loaded)
end
