defmodule P2P.LibP2PTest do
  alias P2P.Transport.LibP2P
  use NamedAccounts
  use ExUnit.Case

  # We're currently using [noise](https://github.com/perlin-network/noise) as a p2p transport layer
  # This test passes but it can be slow an flakey
  @tag :skip
  test "sending and recieving messages" do
    {:ok, client1} =
      GenServer.start_link(
        LibP2P,
        %{
          private_key: @alices_private_key,
          port: 4045,
          bootnodes: []
        },
        []
      )

    {:ok, client2} =
      GenServer.start_link(
        LibP2P,
        %{
          private_key: @bobs_private_key,
          port: 4046,
          bootnodes: [
            [
              "#{Base.encode64(@bob)}:/ip4/127.0.0.1/tcp/4045"
            ]
          ]
        },
        []
      )

    LibP2P.ensure_started(client1)
    LibP2P.ensure_started(client2)
    LibP2P.subscribe(client1, self())
    spawn(fn -> LibP2P.broadcast(client2, "oops\nthing") end)

    receive do
      {:libp2p, _peer_id, message} -> assert message == "oops\nthing"
      message -> assert message == nil
    end
  end
end
