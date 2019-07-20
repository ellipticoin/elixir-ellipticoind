defmodule JSONConfigProvider do
  @behaviour Config.Provider

  def init(path) when is_binary(path), do: path

  def load(config, path) do
    {:ok, _} = Application.ensure_all_started(:jason)

    json = path |> File.read!() |> Jason.decode!()

    Config.Reader.merge(
      config,
      ellipticoind:
        Enum.reduce(json, [], fn {key, value}, acc ->
          [{String.to_atom(key), value} | acc]
        end)
    )
  end
end
