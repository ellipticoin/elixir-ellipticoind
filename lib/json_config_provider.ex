defmodule JSONConfigProvider do
  @behaviour Config.Provider

  # Let's pass the path to the JSON file as config
  def init(path) when is_binary(path), do: path

  def load(config, path) do
    # We need to start any app we may depend on.
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
