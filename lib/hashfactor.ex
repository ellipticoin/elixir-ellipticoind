defmodule Hashfactor do
  @crate "hashfactor"

  def run(data) do
    port = Port.open({:spawn_executable, path_to_executable()},
      args: [
        Base.encode16(data),
        Integer.to_string(Config.hashfactor_target()),
      ],
    )

    receive do
      {_port, {:data, message}} ->
        message
        |> List.to_string()
        |> String.trim("\n")
        |> String.to_integer()
      :cancel ->
        Port.close(port)
        :cancelled
      error -> IO.inspect error
    end
  end

  def valid_nonce?(data, target, nonce) do
    <<numerator::bytes-size(8), _::binary>> = (Crypto.hash(data)
                                              <> :binary.encode_unsigned(nonce, :little))
                                              |> Crypto.hash()



    # IO.inspect "#{:binary.decode_unsigned(numerator, :little)} % #{target + 1}", label: "testing"
    rem(:binary.decode_unsigned(numerator, :little), target + 1) == 0

  end

  def path_to_executable(), do: Application.app_dir(:node, ["priv", "native", @crate])

end
