defmodule JsonLiveviewRender.Stream.Adapter do
  @moduledoc """
  Streaming adapter behavior for provider events.

  API scope:

  - Stability: experimental / deferred
  - Companion package surface for production transport adapters

  Behavior for converting provider-specific payloads into stream events.

  Adapters are intentionally thin translation layers that output one of:
  - `{:root, id}`
  - `{:element, id, element}`
  - `{:finalize}`
  """

  @type normalized :: {:ok, JsonLiveviewRender.Stream.event()} | :ignore | {:error, term()}

  @callback normalize_event(map()) :: normalized()

  @tool_name "json_liveview_render_event"

  @doc "The canonical tool name used by all adapters."
  def tool_name, do: @tool_name

  @doc "Check if a value matches the canonical tool name."
  def tool_name?(name) do
    case to_string_safe(name) do
      {:ok, @tool_name} -> true
      _ -> false
    end
  end

  @doc "Get a value from a map that may have string or atom keys."
  def get_value(map, key) when is_map(map) and is_binary(key) do
    case Map.fetch(map, key) do
      {:ok, value} ->
        value

      :error ->
        atom_key = String.to_existing_atom(key)
        Map.get(map, atom_key)
    end
  rescue
    ArgumentError -> nil
  end

  @doc "Safely convert a value to string. Returns `{:ok, string}` or `:error`."
  def to_string_safe(value) when is_binary(value), do: {:ok, value}

  def to_string_safe(value) when is_atom(value) and not is_nil(value),
    do: {:ok, Atom.to_string(value)}

  def to_string_safe(value) when is_number(value), do: {:ok, to_string(value)}
  def to_string_safe(_), do: :error

  @doc "Recursively normalize map keys to strings. Returns error for non-stringifiable keys."
  def normalize_keys(map) when is_map(map) do
    Enum.reduce_while(Map.to_list(map), {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      with {:ok, str_k} <- stringify_key(k),
           {:ok, normalized_v} <- normalize_keys(v) do
        {:cont, {:ok, Map.put(acc, str_k, normalized_v)}}
      else
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  def normalize_keys(list) when is_list(list) do
    Enum.reduce_while(list, {:ok, []}, fn value, {:ok, acc} ->
      case normalize_keys(value) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      {:error, _} = error -> error
    end
  end

  def normalize_keys(value), do: {:ok, value}

  defp stringify_key(key) when is_binary(key), do: {:ok, key}
  defp stringify_key(key) when is_atom(key), do: {:ok, Atom.to_string(key)}
  defp stringify_key(key), do: {:error, {:invalid_payload_key, key}}
end
