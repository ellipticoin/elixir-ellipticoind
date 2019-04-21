defmodule MockHashfactor do
  def run(_data, _target) do
    1
  end

  def valid_nonce?(_data, _target, _nonce) do
    true
  end
end
