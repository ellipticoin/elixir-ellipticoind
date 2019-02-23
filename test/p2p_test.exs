defmodule P2PTest do
  use ExUnit.Case

  setup do
    Application.put_env(:blacksmith, :bootnode, true)
    Application.put_env(:blacksmith, :bootnodes, ["http://localhost:4047/"])
    restart()

    :ok
  end

  test "initializes with bootnodes without this node" do
    assert P2P.peers() == []
  end

  test "queries a bootnode for peers if it's not a bootnode itself" do
    bootnodes = Application.fetch_env!(:blacksmith, :bootnodes)
    bypass = Bypass.open()
    bootnode = "http://localhost:#{bypass.port}"

    Bypass.expect_once(bypass, "GET", "/peers", fn conn ->
      Plug.Conn.resp(conn, 200, Cbor.encode([bootnode]))
    end)

    Bypass.expect_once(bypass, "POST", "/peers", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Cbor.decode!(body) == %{url: "http://localhost:4047/"}
      Plug.Conn.resp(conn, 200, Cbor.encode(nil))
    end)

    Application.put_env(:blacksmith, :bootnode, false)
    Application.put_env(:blacksmith, :bootnodes, [bootnode])
    restart()

    assert P2P.peers() == [bootnode]
  end

  describe "add_peer" do
    test "doesn't add the peer if it's already been added" do
      bootnodes = Application.fetch_env!(:blacksmith, :bootnodes)

      P2P.add_peer(List.last(bootnodes))

      assert P2P.peers() == bootnodes
    end
  end

  defp restart() do
    Supervisor.terminate_child(Blacksmith.Supervisor, P2P)
    Supervisor.restart_child(Blacksmith.Supervisor, P2P)
  end
end
