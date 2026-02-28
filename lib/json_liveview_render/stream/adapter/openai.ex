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

  alias JsonLiveviewRender.Stream.Adapter

  @tool_name Adapter.tool_name()

  @impl true
  def normalize_event(payload) when is_map(payload) do
    case event_type(payload) do
      :ignore ->
        :ignore

      {:output_item_done} ->
        normalize_output_item(payload)

      {:function_call_arguments_done} ->
        normalize_function_call_arguments(payload)
    end
  end

  def normalize_event(_payload), do: :ignore

  defp event_type(payload) do
    case Adapter.get_value(payload, "type") do
      nil ->
        :ignore

      value ->
        case Adapter.to_string_safe(value) do
          {:ok, "response.output_item.done"} -> {:output_item_done}
          {:ok, "response.function_call_arguments.done"} -> {:function_call_arguments_done}
          {:ok, _} -> :ignore
          :error -> :ignore
        end
    end
  end

  defp normalize_output_item(payload) do
    item = Adapter.get_value(payload, "item")

    if is_map(item) do
      case Adapter.normalize_keys(item) do
        {:ok, normalized_item} -> normalize_output_item_payload(normalized_item, payload)
        {:error, _} -> {:error, {:invalid_adapter_event, payload}}
      end
    else
      {:error, {:invalid_adapter_event, payload}}
    end
  end

  defp normalize_output_item_payload(
         %{"type" => "function_call", "name" => @tool_name, "arguments" => arguments},
         _payload
       ) do
    decode_arguments(arguments) |> map_arguments()
  end

  defp normalize_output_item_payload(
         %{"type" => "function_call", "name" => @tool_name},
         payload
       ),
       do: {:error, {:invalid_adapter_event, payload}}

  defp normalize_output_item_payload(%{"type" => "function_call"}, _payload), do: :ignore
  defp normalize_output_item_payload(_payload, _original), do: :ignore

  defp normalize_function_call_arguments(payload) do
    if Adapter.tool_name?(Adapter.get_value(payload, "name")) do
      payload
      |> Adapter.get_value("arguments")
      |> decode_arguments()
      |> map_arguments()
    else
      :ignore
    end
  end

  defp decode_arguments(arguments) when is_map(arguments) do
    case Adapter.normalize_keys(arguments) do
      {:ok, normalized} -> {:ok, normalized}
      {:error, _} -> {:error, {:invalid_adapter_event, :arguments_must_be_map_or_json}}
    end
  end

  defp decode_arguments(arguments) when is_binary(arguments) do
    case Jason.decode(arguments) do
      {:ok, decoded} when is_map(decoded) ->
        case Adapter.normalize_keys(decoded) do
          {:ok, normalized} -> {:ok, normalized}
          {:error, _} -> {:error, {:invalid_adapter_event, :arguments_must_be_map_or_json}}
        end

      {:ok, _} ->
        {:error, {:invalid_adapter_event, :arguments_must_decode_to_map}}

      {:error, reason} ->
        {:error, {:invalid_adapter_event, {:invalid_json_arguments, reason}}}
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
end
