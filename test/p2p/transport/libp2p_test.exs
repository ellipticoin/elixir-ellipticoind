defmodule P2P.Libp2pTest do
  alias Ellipticoind.Models.Transaction
  alias P2P.Transport.Libp2p
  import Test.Utils
  use NamedAccounts
  use ExUnit.Case

  setup do
    checkout_repo()

    on_exit(fn ->
      Redis.reset()
    end)
  end

  test "sending and recieving messages" do
    {:ok, client1} =
      GenServer.start_link(
        Libp2p,
        %{
          private_key: String.slice(@alices_private_key, 0, 31),
          host: "127.0.0.1",
          port: 4045,
          bootnodes: []
        },
        []
      )

    {:ok, client2} =
      GenServer.start_link(
        Libp2p,
        %{
          private_key: <<0>> <> String.slice(@bobs_private_key, 0, 31),
          host: "127.0.0.1",
          port: 4046,
          bootnodes: [
            "/ip4/127.0.0.1/tcp/4045/p2p/16Uiu2HAmHjiTVfMhqfsfFMFyZMkKtnKwLZpdHvzxYdoLUCKJd3jm"
          ]
        },
        []
      )

    Libp2p.ensure_started(client1)
    Libp2p.ensure_started(client2)

    spawn(fn ->
      Libp2p.broadcast(client2, %Transaction{
        function: :test
      })
    end)

    Libp2p.subscribe(client1, self())


    receive do
      {:p2p, message} ->
        assert message == %Transaction{
          function: :test
        }
    end
  end
end
