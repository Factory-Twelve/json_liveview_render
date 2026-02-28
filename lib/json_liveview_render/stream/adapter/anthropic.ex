defmodule JsonLiveviewRender.Stream.Adapter.Anthropic do
  @moduledoc """
  Example Anthropic adapter for streaming event normalization.

  API scope: experimental reference implementation; transport-level behavior is deferred to companion packages.

  Example adapter for Anthropic `tool_use` style payloads.

  Expected event payloads:

  - `%{"type" => "tool_use", "name" => "...", "input" => %{...}}`
  - `%{"type" => "content_block_stop", "content_block" => %{"type" => "tool_use", "name" => "...", "input" => %{...}}}`

  Where `input` contains:

  - `%{"event" => "root", "id" => "..."}`
  - `%{"event" => "element", "id" => "...", "element" => %{...}}`
  - `%{"event" => "finalize"}`
  """

  @behaviour JsonLiveviewRender.Stream.Adapter

  @tool_name "json_liveview_render_event"

  @impl true
  def normalize_event(payload) when is_map(payload) do
    case normalize_payload_keys(payload) do
      {:ok, normalized_payload} ->
        case normalized_payload do
          %{"type" => "tool_use", "name" => @tool_name, "input" => input} ->
            map_input(input)

          %{"type" => "tool_use", "name" => @tool_name} ->
            {:error, {:invalid_adapter_event, normalized_payload}}

          %{
            "type" => "content_block_stop",
            "content_block" => %{"type" => "tool_use", "name" => @tool_name, "input" => input}
          } ->
            map_input(input)

          %{
            "type" => "content_block_stop",
            "content_block" => %{"type" => "tool_use", "name" => @tool_name}
          } ->
            {:error, {:invalid_adapter_event, normalized_payload}}

          _ ->
            :ignore
        end

      {:error, _} ->
        {:error, {:invalid_adapter_event, payload}}
    end
  end

  def normalize_event(_payload), do: :ignore

  defp map_input(%{"event" => "root", "id" => id}) when is_binary(id),
    do: {:ok, {:root, id}}

  defp map_input(%{"event" => "element", "id" => id, "element" => element})
       when is_binary(id) and is_map(element),
       do: {:ok, {:element, id, element}}

  defp map_input(%{"event" => "finalize"}), do: {:ok, {:finalize}}

  defp map_input(payload) when is_map(payload) do
    case normalize_payload_keys(payload) do
      {:ok, normalized_payload} -> {:error, {:invalid_adapter_event, normalized_payload}}
      {:error, _} -> {:error, {:invalid_adapter_event, payload}}
    end
  end

  defp map_input(payload), do: {:error, {:invalid_adapter_event, payload}}

  defp normalize_payload_keys(map) when is_map(map) do
    Enum.reduce_while(Map.to_list(map), {:ok, %{}}, fn {k, v}, {:ok, normalized_map} ->
      with {:ok, normalized_k} <- normalize_payload_key(k),
           {:ok, normalized_v} <- normalize_payload_keys(v) do
        {:cont, {:ok, Map.put(normalized_map, normalized_k, normalized_v)}}
      else
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp normalize_payload_keys(list) when is_list(list) do
    list
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, acc} ->
      case normalize_payload_keys(value) do
        {:ok, normalized_value} -> {:cont, {:ok, [normalized_value | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_payload_keys(value), do: {:ok, value}

  defp normalize_payload_key(key) do
    {:ok, to_string(key)}
  rescue
    Protocol.UndefinedError ->
      {:error, {:invalid_payload_key, key}}
  end
end
