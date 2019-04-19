defmodule Mix.Tasks.GeneratePrivateKey do
  use Mix.Task

  @shortdoc "Seeds the database"
  def run(_) do
    IO.puts("New private_key:")

    IO.puts(
      Crypto.keypair()
      |> elem(1)
      |> Base.encode64()
    )
  end
end
