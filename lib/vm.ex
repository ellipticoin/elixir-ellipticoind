defmodule VM do
  use Rustler, otp_app: :blacksmith, crate: :vm

  def add(_arg1, _arg2), do: exit(:nif_not_loaded)
end
