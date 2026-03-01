defmodule JsonLiveviewRender.Companion.ChatCards.Platform.Slack do
  @moduledoc """
  Internal companion renderer for Slack Block Kit payloads.
  """

  @behaviour JsonLiveviewRender.Companion.ChatCards.Target

  alias JsonLiveviewRender.Companion.ChatCards.IR
  alias JsonLiveviewRender.Companion.ChatCards.Platform.Limits

  @doc false
  @impl true
  @spec render(IR.t(), keyword()) :: {:ok, map(), list(), list()} | {:error, term()}
  def render(ir, opts) do
    surface = Keyword.get(opts, :slack_surface, :message)

    with :ok <- validate_surface(surface) do
      {title, title_warnings} = Limits.truncate_text(ir.title, 150, :slack, ["header", "text"])

      body_text =
        (ir.body_lines ++ IR.fact_lines(ir))
        |> Enum.reject(&(&1 in [nil, ""]))
        |> Enum.join("\n")

      {section_text, section_warnings} =
        Limits.truncate_text(body_text, 3000, :slack, ["section", "text"])

      blocks =
        [
          header_block(title),
          severity_block(ir.severity),
          section_block(section_text),
          actions_block(ir.actions)
        ]
        |> Enum.reject(&is_nil/1)

      {trimmed_blocks, limit_warnings} = Limits.slack_trim_blocks(blocks, surface)

      payload =
        case surface do
          :message ->
            %{"blocks" => trimmed_blocks}

          :home ->
            %{"type" => "home", "blocks" => trimmed_blocks}

          :modal ->
            {modal_title, modal_warnings} =
              Limits.truncate_text(title, 24, :slack, ["modal", "title"])

            payload = %{
              "type" => "modal",
              "title" => %{"type" => "plain_text", "text" => blank_fallback(modal_title, "Card")},
              "close" => %{"type" => "plain_text", "text" => "Close"},
              "blocks" => trimmed_blocks
            }

            {payload, modal_warnings}
        end

      {final_payload, modal_warnings} = unwrap_payload(payload)

      actions = Enum.map(ir.actions, &%{action_id: &1.action_id, metadata: &1.metadata})

      warnings =
        title_warnings ++ section_warnings ++ limit_warnings ++ modal_warnings

      {:ok, final_payload, warnings, actions}
    end
  end

  defp validate_surface(surface) when surface in [:message, :home, :modal], do: :ok
  defp validate_surface(surface), do: {:error, {:unsupported_slack_surface, surface}}

  defp header_block(nil), do: nil
  defp header_block(""), do: nil

  defp header_block(title) do
    %{"type" => "header", "text" => %{"type" => "plain_text", "text" => title}}
  end

  defp severity_block(nil), do: nil
  defp severity_block(""), do: nil

  defp severity_block(severity) do
    %{
      "type" => "context",
      "elements" => [%{"type" => "mrkdwn", "text" => "*#{String.upcase(severity)}*"}]
    }
  end

  defp section_block(nil), do: nil
  defp section_block(""), do: nil

  defp section_block(text) do
    %{"type" => "section", "text" => %{"type" => "mrkdwn", "text" => text}}
  end

  defp actions_block([]), do: nil

  defp actions_block(actions) do
    elements =
      Enum.map(actions, fn action ->
        base = %{
          "type" => "button",
          "text" => %{"type" => "plain_text", "text" => action.label},
          "action_id" => action.action_id,
          "value" => action.action_id
        }

        case action.style do
          "danger" -> Map.put(base, "style", "danger")
          "primary" -> Map.put(base, "style", "primary")
          _ -> base
        end
      end)

    %{"type" => "actions", "elements" => elements}
  end

  defp blank_fallback("", fallback), do: fallback
  defp blank_fallback(nil, fallback), do: fallback
  defp blank_fallback(text, _fallback), do: text

  defp unwrap_payload({payload, warnings}), do: {payload, warnings}
  defp unwrap_payload(payload), do: {payload, []}
end
