defmodule Crypto.SHA256 do
  def hash(message), do: :crypto.hash(:sha256, message)
end
