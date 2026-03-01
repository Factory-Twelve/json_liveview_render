defmodule JsonLiveviewRender.Companion.ChatCards.Platform.LiveView do
  @moduledoc """
  Internal companion renderer for LiveView reference output payloads.
  """

  @behaviour JsonLiveviewRender.Companion.ChatCards.Target

  alias JsonLiveviewRender.Companion.ChatCards.IR

  @doc false
  @impl true
  @spec render(IR.t(), keyword()) :: {:ok, map(), list(), list()}
  def render(ir, _opts) do
    payload = %{
      "type" => "liveview_spec",
      "spec" => ir.filtered_spec,
      "card" => %{
        "id" => ir.card_id,
        "title" => ir.title,
        "severity" => ir.severity,
        "body" => ir.body_lines,
        "facts" => Enum.map(ir.facts, &stringify_keys/1),
        "actions" =>
          Enum.map(ir.actions, fn action ->
            %{
              "id" => action.action_id,
              "label" => action.label,
              "style" => action.style,
              "metadata" => stringify_keys(action.metadata)
            }
          end)
      },
      "css_reference_path" => "docs/companion/chat_cards_reference.css"
    }

    actions = Enum.map(ir.actions, &%{action_id: &1.action_id, metadata: &1.metadata})
    {:ok, payload, [], actions}
  end

  defp stringify_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      Map.put(acc, to_string(key), stringify_keys(value))
    end)
  end

  defp stringify_keys(list) when is_list(list), do: Enum.map(list, &stringify_keys/1)
  defp stringify_keys(value), do: value
end
