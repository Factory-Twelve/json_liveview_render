defmodule JsonLiveviewRender.Companion.ChatCards.Platform.WhatsApp do
  @moduledoc """
  Internal companion renderer for WhatsApp Business API interactive message payloads.
  """

  @behaviour JsonLiveviewRender.Companion.ChatCards.Target

  alias JsonLiveviewRender.Companion.ChatCards.IR
  alias JsonLiveviewRender.Companion.ChatCards.Platform.Limits

  @doc false
  @impl true
  @spec render(IR.t(), keyword()) :: {:ok, map(), list(), list()}
  def render(ir, opts) do
    mode = Keyword.get(opts, :whatsapp_mode, :auto)
    action_items = Enum.map(ir.actions, &to_action_item/1)

    resolved_mode = Limits.whatsapp_mode(mode, action_items)

    message =
      ([ir.title] ++ ir.body_lines ++ IR.fact_lines(ir))
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join("\n\n")

    {body_text, body_warnings} =
      Limits.truncate_text(message, 1024, :whatsapp, ["interactive", "body", "text"])

    case resolved_mode do
      :buttons ->
        render_buttons(body_text, body_warnings, action_items)

      :list ->
        render_list(body_text, body_warnings, action_items)
    end
  end

  defp render_buttons(body_text, body_warnings, action_items) do
    {trimmed_buttons, button_warnings} = Limits.whatsapp_trim_buttons(action_items)

    buttons =
      Enum.map(trimmed_buttons, fn button ->
        %{"type" => "reply", "reply" => %{"id" => button["id"], "title" => button["title"]}}
      end)

    payload = %{
      "messaging_product" => "whatsapp",
      "type" => "interactive",
      "interactive" => %{
        "type" => "button",
        "body" => %{"text" => body_text},
        "action" => %{"buttons" => buttons}
      }
    }

    actions =
      Enum.map(trimmed_buttons, fn button ->
        %{action_id: button["id"], metadata: %{mode: "buttons"}}
      end)

    {:ok, payload, body_warnings ++ button_warnings, actions}
  end

  defp render_list(body_text, body_warnings, action_items) do
    {trimmed_rows, row_warnings} = Limits.whatsapp_trim_list_rows(action_items)

    {button_label, button_warnings} =
      Limits.truncate_text("Choose action", 20, :whatsapp, ["interactive", "action", "button"])

    rows =
      Enum.map(trimmed_rows, fn row ->
        %{
          "id" => row["id"],
          "title" => row["title"],
          "description" => row["description"]
        }
      end)

    payload = %{
      "messaging_product" => "whatsapp",
      "type" => "interactive",
      "interactive" => %{
        "type" => "list",
        "body" => %{"text" => body_text},
        "action" => %{
          "button" => button_label,
          "sections" => [%{"title" => "Actions", "rows" => rows}]
        }
      }
    }

    actions =
      Enum.map(trimmed_rows, fn row -> %{action_id: row["id"], metadata: %{mode: "list"}} end)

    {:ok, payload, body_warnings ++ row_warnings ++ button_warnings, actions}
  end

  defp to_action_item(action) do
    %{
      "id" => action.action_id,
      "title" => action.label,
      "description" => action.metadata |> inspect()
    }
  end
end
