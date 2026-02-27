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
  def normalize_event(%{"type" => "tool_use", "name" => @tool_name, "input" => input})
      when is_map(input) do
    map_input(input)
  end

  def normalize_event(%{
        "type" => "content_block_stop",
        "content_block" => %{
          "type" => "tool_use",
          "name" => @tool_name,
          "input" => input
        }
      })
      when is_map(input) do
    map_input(input)
  end

  def normalize_event(_payload), do: :ignore

  defp map_input(%{"event" => "root", "id" => id}) when is_binary(id),
    do: {:ok, {:root, id}}

  defp map_input(%{"event" => "element", "id" => id, "element" => element})
       when is_binary(id) and is_map(element),
       do: {:ok, {:element, id, element}}

  defp map_input(%{"event" => "finalize"}), do: {:ok, {:finalize}}
  defp map_input(payload), do: {:error, {:invalid_adapter_event, payload}}
end
