defmodule Hashfactor do
  @crate "hashfactor"

  def run(data) do
    port =
      Port.open({:spawn_executable, path_to_executable()},
        args: [
          Integer.to_string(Config.hashfactor_target())
        ]
      )
    send(port, {self(), {:command, Base.encode64(data) <> "\n"}})
    receive do
      {_port, {:data, message}} ->
        message
        |> List.to_string()
        |> String.trim("\n")
        |> String.to_integer()

      :cancel ->
        Port.close(port)
        :cancelled

      message ->
        IO.puts(message)
    end
  end

  def valid_nonce?(data, nonce) do
    <<numerator::bytes-size(8), _::binary>> =
      (Crypto.hash(data) <>
         :binary.encode_unsigned(nonce, :little))
      |> Crypto.hash()

    target = Config.hashfactor_target()
    rem(:binary.decode_unsigned(numerator, :little), target + 1) == 0
  end

  def path_to_executable(), do: Application.app_dir(:ellipticoind, ["priv", "native", @crate])
end
