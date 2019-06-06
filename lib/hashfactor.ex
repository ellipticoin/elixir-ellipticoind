defmodule Hashfactor do
  use NativeModule

  def args() do
    [Integer.to_string(Config.hashfactor_target())]
  end

  def run(data) do
    GenServer.call(__MODULE__, {:run, data})
  end


  def handle_call({:run, data}, _from, port) do
    call_native(port, :run, [data])
    case receive_native(port) do
      :cancel ->
        Port.close(port)
        {:reply, :cancelled, port}
      hashfactor_value ->
        {:reply, hashfactor_value, port}
    end
  end


  def receive_native(port) do
    receive_cancel_or_message(port)
    |> List.to_string()
    |> String.trim("\n")
    |> Base.decode64!()
    |> Cbor.decode!()
  end


  def receive_cancel_or_message(_port, message \\ '') do
    receive do
      {_port, {:data, message_part}} ->
        if length(message_part) > 65535 do
          receive_cancel_or_message(_port, Enum.concat(message, message_part))
        else
          Enum.concat(message, message_part)
        end
      :cancel -> :cancel
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
  #
  # def path_to_executable(), do: Application.app_dir(:ellipticoind, ["priv", "native", @crate])
end
