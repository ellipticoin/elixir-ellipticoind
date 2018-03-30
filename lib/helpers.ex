defmodule Helpers do
  def pad_bytes_right(n, size \\ 32) do
    padding_size = (size - byte_size(n)) * bit_size(<<0>>)
    n <> <<0:: size(padding_size)>>
  end
end
