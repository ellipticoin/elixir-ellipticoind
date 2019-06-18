defmodule P2P.Messages do
  use Protobuf, from: Path.expand("../../native/noise/ellipticoin.proto", __DIR__)
end
