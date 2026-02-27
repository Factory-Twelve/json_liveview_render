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
  def normalize_event(%{
        "type" => "response.output_item.done",
        "item" => %{"type" => "function_call", "name" => @tool_name, "arguments" => arguments}
      }) do
    arguments |> decode_arguments() |> map_arguments()
  end

  def normalize_event(%{
        "type" => "response.function_call_arguments.done",
        "name" => @tool_name,
        "arguments" => arguments
      }) do
    arguments |> decode_arguments() |> map_arguments()
  end

  def normalize_event(_payload), do: :ignore

  defp decode_arguments(arguments) when is_map(arguments), do: {:ok, arguments}

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
end
