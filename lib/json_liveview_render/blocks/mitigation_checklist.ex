defmodule JsonLiveviewRender.Blocks.MitigationChecklist do
  @moduledoc """
  Internal experimental mitigation checklist renderer for reusable depth review
  panels.
  """

  use Phoenix.Component

  alias JsonLiveviewRender.Blocks.PreviewHelpers

  attr(:checklist_id, :string, required: true)
  attr(:summary, :string, default: nil)
  attr(:items, :list, default: [])
  attr(:children, :list, default: [])

  def render(assigns) do
    assigns = Map.put(assigns, :normalized_items, normalize_items(assigns.items))

    ~H"""
    <article class="genui-mitigation-checklist" data-checklist-id={@checklist_id}>
      <header class="genui-mitigation-checklist__header">
        <h4>Mitigation checklist</h4>
      </header>
      <p :if={@summary} class="genui-mitigation-checklist__summary"><%= @summary %></p>
      <ul :if={@normalized_items != []} class="genui-mitigation-checklist__items">
        <li
          :for={item <- @normalized_items}
          class="genui-mitigation-checklist__item"
          data-item-id={item.item_id}
          data-status={item.status}
          data-blocking={item.blocking}
        >
          <div class="genui-mitigation-checklist__item-header">
            <strong><%= item.label %></strong>
            <span><%= item.status %></span>
            <span :if={item.severity}><%= item.severity %></span>
            <span :if={item.blocking}>blocking</span>
          </div>
          <p :if={item.summary} class="genui-mitigation-checklist__item-summary">
            <%= item.summary %>
          </p>
          <p :if={item.condition} class="genui-mitigation-checklist__item-condition">
            If: <%= item.condition %>
          </p>
          <dl class="genui-mitigation-checklist__item-meta">
            <div :if={item.owner}>
              <dt>Owner</dt>
              <dd><%= item.owner %></dd>
            </div>
            <div :if={item.due_at}>
              <dt>Due</dt>
              <dd><%= item.due_at %></dd>
            </div>
          </dl>
        </li>
      </ul>
      <p :if={@normalized_items == []} class="genui-mitigation-checklist__empty">
        No mitigation steps.
      </p>
      <div :if={@children != []} class="genui-mitigation-checklist__children">
        <%= for child <- @children do %>
          <%= child %>
        <% end %>
      </div>
    </article>
    """
  end

  defp normalize_items(items) do
    items
    |> Enum.map(&normalize_item/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_item(item) when is_map(item) do
    item_id = PreviewHelpers.string(item, :item_id)
    label = PreviewHelpers.string(item, :label)
    status = PreviewHelpers.string(item, :status)

    if filled?(item_id) and filled?(label) and filled?(status) do
      %{
        item_id: item_id,
        label: label,
        status: status,
        blocking: PreviewHelpers.boolean(item, :blocking),
        summary: PreviewHelpers.string(item, :summary),
        condition: PreviewHelpers.string(item, :condition),
        owner: PreviewHelpers.string(item, :owner),
        due_at: PreviewHelpers.string(item, :due_at),
        severity: PreviewHelpers.string(item, :severity)
      }
    end
  end

  defp normalize_item(_item), do: nil

  defp filled?(value) when is_binary(value), do: value != ""
  defp filled?(_value), do: false
end
