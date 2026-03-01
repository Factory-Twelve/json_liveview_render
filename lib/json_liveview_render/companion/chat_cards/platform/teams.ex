defmodule JsonLiveviewRender.Companion.ChatCards.Platform.Teams do
  @moduledoc """
  Internal companion renderer for Microsoft Teams Adaptive Cards payloads.
  """

  @behaviour JsonLiveviewRender.Companion.ChatCards.Target

  alias JsonLiveviewRender.Companion.ChatCards.IR

  @doc false
  @impl true
  @spec render(IR.t(), keyword()) :: {:ok, map(), list(), list()}
  def render(ir, _opts) do
    facts =
      Enum.map(ir.facts, fn fact ->
        fact = stringify_keys(fact)
        %{"title" => fact["label"], "value" => fact["value"]}
      end)

    body =
      [
        %{"type" => "TextBlock", "text" => ir.title, "size" => "Large", "weight" => "Bolder"},
        severity_block(ir.severity),
        %{"type" => "TextBlock", "text" => Enum.join(ir.body_lines, "\n"), "wrap" => true},
        %{"type" => "FactSet", "facts" => facts}
      ]
      |> Enum.reject(&is_nil/1)

    actions =
      Enum.map(ir.actions, fn action ->
        %{
          "type" => "Action.Submit",
          "title" => action.label,
          "style" => teams_style(action.style),
          "data" =>
            %{"action" => action.action_id, "metadata" => action.metadata}
            |> stringify_keys()
        }
      end)

    payload = %{
      "$schema" => "http://adaptivecards.io/schemas/adaptive-card.json",
      "type" => "AdaptiveCard",
      "version" => "1.5",
      "body" => body,
      "actions" => actions
    }

    action_refs = Enum.map(ir.actions, &%{action_id: &1.action_id, metadata: &1.metadata})
    {:ok, payload, [], action_refs}
  end

  defp severity_block(nil), do: nil

  defp severity_block(severity) do
    %{
      "type" => "TextBlock",
      "text" => String.upcase(severity),
      "color" => teams_severity_color(severity),
      "size" => "Small"
    }
  end

  defp teams_style("danger"), do: "destructive"
  defp teams_style("primary"), do: "positive"
  defp teams_style(_), do: nil

  defp teams_severity_color("critical"), do: "Attention"
  defp teams_severity_color("warning"), do: "Warning"
  defp teams_severity_color(_), do: "Default"

  defp stringify_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      Map.put(acc, to_string(key), stringify_keys(value))
    end)
  end

  defp stringify_keys(list) when is_list(list), do: Enum.map(list, &stringify_keys/1)
  defp stringify_keys(value), do: value
end
