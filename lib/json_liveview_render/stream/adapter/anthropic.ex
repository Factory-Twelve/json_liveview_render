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
    payload = normalize_payload_keys(payload)

    case payload do
      %{"type" => "tool_use", "name" => @tool_name, "input" => input} ->
        map_input(input)

      %{"type" => "tool_use", "name" => @tool_name} ->
        {:error, {:invalid_adapter_event, payload}}

      %{
        "type" => "content_block_stop",
        "content_block" => %{"type" => "tool_use", "name" => @tool_name, "input" => input}
      } ->
        map_input(input)

      %{
        "type" => "content_block_stop",
        "content_block" => %{"type" => "tool_use", "name" => @tool_name}
      } ->
        {:error, {:invalid_adapter_event, payload}}

      _ ->
        :ignore
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
    {:error, {:invalid_adapter_event, normalize_payload_keys(payload)}}
  end

  defp map_input(payload), do: {:error, {:invalid_adapter_event, payload}}

  defp normalize_payload_keys(map) when is_map(map),
    do: Map.new(map, fn {k, v} -> {to_string(k), normalize_payload_keys(v)} end)

  defp normalize_payload_keys(list) when is_list(list),
    do: Enum.map(list, &normalize_payload_keys/1)

  defp normalize_payload_keys(value), do: value
end
