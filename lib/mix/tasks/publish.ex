defmodule Mix.Tasks.Publish do
  use Mix.Task

  @shortdoc "Publish a release to IPFS"
  def run(_) do
    {cwd, 0} = System.cmd("pwd", [])
    cwd = cwd |> String.replace("\n", "")

    System.cmd("docker", [
      "build",
      "-t",
      "ellipticoin-builder",
      "."
    ])
    |> elem(0)
    |> IO.puts()

    System.cmd("docker", [
      "run",
      "-v#{cwd}:/build",
      "ellipticoin-builder",
      "sh",
      "-c",
      "cat /build/config/prod.exs && . /root/.cargo/env && cd build && MIX_ENV=prod mix release --env=prod"
    ])
    |> elem(0)
    |> IO.puts()
  end
end
