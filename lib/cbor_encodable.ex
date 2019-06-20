defmodule CborEncodable do
  defmacro __using__(_opts) do
    quote do
      def hash(block), do: Crypto.hash(as_binary(block))

      def from_binary(bytes) do
        attributes = Cbor.decode!(bytes)

        struct(__MODULE__, attributes)
      end

      def as_binary(block),
        do:
          as_map(block)
          |> Cbor.encode()
    end
  end
end
