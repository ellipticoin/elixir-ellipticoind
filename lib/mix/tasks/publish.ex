defmodule Mix.Tasks.Publish do
  use Mix.Task

  @shortdoc "Publish a release to IPFS"
  def run(_) do
    {cwd, 0} = System.cmd("pwd", []);
    cwd = cwd |> String.replace("\n", "")
    IO.inspect System.cmd("docker", ["run", "-v#{cwd}:/build", "elipticoin-builder", "sh", "-c", "cat /build/config/prod.exs && . /root/.cargo/env && cd build && MIX_ENV=prod mix release --env=prod"])
  end
end
