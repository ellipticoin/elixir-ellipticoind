defmodule NativeModule do
  defmacro __using__(_opts) do
    quote do
      use GenServer
      def start_link(opts) do
        GenServer.start_link(__MODULE__, %{}, opts)
      end

      def init(_init_arg) do
        port = Port.open({:spawn_executable, path_to_executable()},
          args: args()
        )

        {:ok, port}
      end

      def call_native(port, command, args) do
        encoded_args = Enum.map(args, fn (arg)-> cond do
          is_map(arg) -> Cbor.encode(arg) |> Base.encode64
          is_integer(arg) -> Integer.to_string(arg)
          is_binary(arg) -> Base.encode64(arg)
        end
        end)
        |> Enum.join(" ")
        payload = "#{command} " <> encoded_args <> "\n"
        send(port, {self(), {:command, payload}})
      end

      def crate, do:
        __MODULE__
          |> to_string()
          |> String.split(".")
          |> List.last
          |> Macro.underscore()
      def path_to_executable(), do: Application.app_dir(:ellipticoind, ["priv", "native", crate()])
    end
  end
end
