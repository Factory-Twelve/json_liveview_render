defmodule JsonLiveviewRender.Blocks.PreviewHelpers do
  @moduledoc false

  @spec value(map(), atom(), term()) :: term()
  def value(map, key, default \\ nil)

  def value(map, key, default) when is_map(map) and is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  def value(_map, _key, default), do: default

  @spec string(map(), atom(), String.t() | nil) :: String.t() | nil
  def string(map, key, default \\ nil) do
    case value(map, key, default) do
      nil -> default
      value -> to_string(value)
    end
  end

  @spec list(map(), atom()) :: list()
  def list(map, key) do
    case value(map, key, []) do
      value when is_list(value) -> value
      _other -> []
    end
  end

  @spec integer(map(), atom(), integer()) :: integer()
  def integer(map, key, default \\ 0) do
    case value(map, key, default) do
      value when is_integer(value) -> value
      _other -> default
    end
  end
end
