defmodule P2P.NoiseTest do
  alias P2P.Transport.Noise
  import Test.Utils
  use NamedAccounts
  use ExUnit.Case

  setup do
    checkout_repo()

    on_exit(fn ->
      Redis.reset()
      File.rm_rf!(Config.rocksdb_path())
    end)
  end

  test "sending and recieving messages" do
    {:ok, client1} =
      GenServer.start_link(
        Noise,
        %{
          private_key: @alices_private_key,
          host: "127.0.0.1",
          port: 4045,
          bootnodes: []
        },
        []
      )

    {:ok, client2} =
      GenServer.start_link(
        Noise,
        %{
          private_key: @bobs_private_key,
          host: "127.0.0.1",
          port: 4046,
          bootnodes: [
            "127.0.0.1:4045"
          ]
        },
        []
      )

    Noise.ensure_started(client1)
    Noise.ensure_started(client2)
    spawn(fn -> Noise.broadcast(client2, "message") end)
    Noise.subscribe(client1, self())

    receive do
      {:p2p, _peer_id, message} -> assert message == "message"
    end
  end
end
