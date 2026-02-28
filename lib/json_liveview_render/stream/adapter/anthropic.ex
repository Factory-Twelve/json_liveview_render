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

  alias JsonLiveviewRender.Stream.Adapter

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
    case Adapter.get_value(payload, "type") do
      nil ->
        :ignore

      value ->
        case Adapter.to_string_safe(value) do
          {:ok, "tool_use"} -> {:tool_use}
          {:ok, "content_block_stop"} -> {:content_block_stop}
          {:ok, _} -> :ignore
          :error -> :ignore
        end
    end
  end

  defp normalize_tool_use(payload) do
    if Adapter.tool_name?(Adapter.get_value(payload, "name")) do
      map_input(Adapter.get_value(payload, "input"))
    else
      :ignore
    end
  end

  defp normalize_content_block_stop(payload) do
    case Adapter.get_value(payload, "content_block") do
      content_block when is_map(content_block) ->
        is_tool_use = is_tool_use?(Adapter.get_value(content_block, "type"))
        has_tool_name = Adapter.tool_name?(Adapter.get_value(content_block, "name"))

        if is_tool_use and has_tool_name do
          map_input(Adapter.get_value(content_block, "input"))
        else
          :ignore
        end

      _ ->
        :ignore
    end
  end

  defp is_tool_use?(value) do
    case Adapter.to_string_safe(value) do
      {:ok, "tool_use"} -> true
      _ -> false
    end
  end

  defp map_input(payload) when is_map(payload) do
    case Adapter.normalize_keys(payload) do
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
end
