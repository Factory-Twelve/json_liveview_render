defmodule JsonLiveviewRender.Stream.Adapter.OpenAI do
  @moduledoc """
  Example OpenAI adapter for streaming event normalization.

  API scope: experimental reference implementation; transport-level behavior is deferred to companion packages.

  Example adapter for OpenAI tool/function-call style event payloads.

  Expected event payloads:

  - `%{"type" => "response.output_item.done", "item" => %{"type" => "function_call", "name" => "...", "arguments" => ...}}`
  - `%{"type" => "response.function_call_arguments.done", "name" => "...", "arguments" => ...}`

  Where `arguments` encode:

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
      %{"type" => "response.output_item.done", "item" => item} ->
        item = normalize_payload_keys(item)

        case item do
          %{"type" => "function_call", "name" => @tool_name, "arguments" => arguments} ->
            decode_arguments(arguments) |> map_arguments()

          %{"type" => "function_call", "name" => @tool_name} ->
            {:error, {:invalid_adapter_event, payload}}

          %{"type" => "function_call"} ->
            :ignore

          _ ->
            :ignore
        end

      %{
        "type" => "response.function_call_arguments.done",
        "name" => @tool_name,
        "arguments" => arguments
      } ->
        decode_arguments(arguments) |> map_arguments()

      %{"type" => "response.function_call_arguments.done", "name" => @tool_name} ->
        {:error, {:invalid_adapter_event, payload}}

      _ ->
        :ignore
    end
  end

  def normalize_event(_payload), do: :ignore

  defp decode_arguments(arguments) when is_map(arguments),
    do: {:ok, normalize_payload_keys(arguments)}

  defp decode_arguments(arguments) when is_binary(arguments) do
    case Jason.decode(arguments) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      {:ok, _} -> {:error, {:invalid_adapter_event, :arguments_must_decode_to_map}}
      {:error, reason} -> {:error, {:invalid_adapter_event, {:invalid_json_arguments, reason}}}
    end
  end

  defp decode_arguments(_), do: {:error, {:invalid_adapter_event, :arguments_must_be_map_or_json}}

  defp map_arguments({:error, reason}), do: {:error, reason}

  defp map_arguments({:ok, %{"event" => "root", "id" => id}}) when is_binary(id),
    do: {:ok, {:root, id}}

  defp map_arguments({:ok, %{"event" => "element", "id" => id, "element" => element}})
       when is_binary(id) and is_map(element),
       do: {:ok, {:element, id, element}}

  defp map_arguments({:ok, %{"event" => "finalize"}}), do: {:ok, {:finalize}}

  defp map_arguments({:ok, payload}), do: {:error, {:invalid_adapter_event, payload}}

  defp normalize_payload_keys(map) when is_map(map),
    do: Map.new(map, fn {k, v} -> {to_string(k), normalize_payload_keys(v)} end)

  defp normalize_payload_keys(list) when is_list(list),
    do: Enum.map(list, &normalize_payload_keys/1)

  defp normalize_payload_keys(value), do: value
end
