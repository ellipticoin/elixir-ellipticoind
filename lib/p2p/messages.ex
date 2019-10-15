defmodule P2P.Messages do
  use Protobuf, from: Path.expand("../../native/noise/ellipticoin.proto", __DIR__)

  def encode(message) do
    apply(message.__struct__, :as_binary, [message])
    |> (&apply(module(message), :new, [[bytes: &1]])).()
    |> (&apply(module(message), :encode, [&1])).()
  end

  def decode(raw_message, type) do
    apply(module(type), :decode, [raw_message])
    |> Map.get(:bytes)
    |> Cbor.decode!()
    |> (&struct(model(type), &1)).()
  end

  def module(%{__struct__: _} = message),
    do: String.to_existing_atom("Elixir.P2P.Messages.#{type(message)}")

  def module(type), do: String.to_existing_atom("Elixir.P2P.Messages.#{type}")

  def model(type), do: String.to_existing_atom("Elixir.Ellipticoind.Models.#{type}")

  def type(module), do: module.__struct__ |> to_string() |> String.split(".") |> List.last()
end
