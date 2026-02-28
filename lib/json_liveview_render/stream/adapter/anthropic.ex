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
    case event_type(payload) do
      :ignore ->
        :ignore

      {:tool_use} ->
        normalize_tool_use(payload)

      {:content_block_stop} ->
        normalize_content_block_stop(payload)
    end
  end

  def normalize_event(_payload), do: :ignore

  defp event_type(payload) do
    case get_payload_value(payload, "type") do
      nil ->
        :ignore

      value ->
        case to_string_safe(value) do
          {:ok, "tool_use"} -> {:tool_use}
          {:ok, "content_block_stop"} -> {:content_block_stop}
          {:ok, _} -> :ignore
          :error -> :ignore
        end
    end
  end

  defp normalize_tool_use(payload) do
    name = get_payload_value(payload, "name")

    if tool_name?(name) do
      map_input(get_payload_value(payload, "input"))
    else
      :ignore
    end
  end

  defp normalize_content_block_stop(payload) do
    case get_payload_value(payload, "content_block") do
      content_block when is_map(content_block) ->
        is_tool_use = is_tool_use?(get_payload_value(content_block, "type"))
        has_tool_name = tool_name?(get_payload_value(content_block, "name"))

        if is_tool_use and has_tool_name do
          map_input(get_payload_value(content_block, "input"))
        else
          :ignore
        end

      _ ->
        :ignore
    end
  end

  defp is_tool_use?(value) do
    case to_string_safe(value) do
      {:ok, "tool_use"} -> true
      _ -> false
    end
  end

  defp tool_name?(name) do
    case to_string_safe(name) do
      {:ok, @tool_name} ->
        true

      _ ->
        false
    end
  end

  defp map_input(payload) when is_map(payload) do
    case normalize_payload_keys(payload) do
      {:ok, %{"event" => "root", "id" => id}} when is_binary(id) ->
        {:ok, {:root, id}}

      {:ok, %{"event" => "element", "id" => id, "element" => element}}
      when is_binary(id) and is_map(element) ->
        {:ok, {:element, id, element}}

      {:ok, %{"event" => "finalize"}} ->
        {:ok, {:finalize}}

      {:ok, normalized_payload} ->
        {:error, {:invalid_adapter_event, normalized_payload}}

      {:error, _} ->
        {:error, {:invalid_adapter_event, payload}}
    end
  end

  defp map_input(payload), do: {:error, {:invalid_adapter_event, payload}}

  defp get_payload_value(payload, key) when is_map(payload) do
    Map.get(payload, key) || Map.get(payload, String.to_atom(key))
  end

  defp to_string_safe(value) do
    try do
      {:ok, to_string(value)}
    rescue
      _ -> :error
    end
  end

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
    _ ->
      {:error, {:invalid_payload_key, key}}
  end
end
