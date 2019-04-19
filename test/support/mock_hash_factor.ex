defmodule MockHashfactor do
  def run(data, target) do
    1
  end

  def valid_nonce?(_data, _target, _nonce) do
    true
  end
end
