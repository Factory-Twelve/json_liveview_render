defmodule JsonLiveviewRender.Blocks.RevisionDeltaSummary do
  @moduledoc """
  Internal experimental revision delta renderer for reusable lifecycle detail
  and review panels.
  """

  use Phoenix.Component

  alias JsonLiveviewRender.Blocks.PreviewHelpers

  attr(:revision_id, :string, required: true)
  attr(:revision_label, :string, required: true)
  attr(:status, :string, required: true)
  attr(:summary, :string, required: true)
  attr(:baseline_label, :string, default: nil)
  attr(:candidate_label, :string, default: nil)
  attr(:changed_at, :string, default: nil)
  attr(:changed_by, :string, default: nil)
  attr(:change_counts, :list, default: [])
  attr(:change_items, :list, default: [])
  attr(:children, :list, default: [])

  def render(assigns) do
    assigns =
      assigns
      |> Map.put(:normalized_counts, normalize_counts(assigns.change_counts))
      |> Map.put(:normalized_items, normalize_items(assigns.change_items))

    ~H"""
    <article
      class="genui-revision-delta-summary"
      data-revision-id={@revision_id}
      data-status={@status}
    >
      <header class="genui-revision-delta-summary__header">
        <span class="genui-revision-delta-summary__status"><%= @status %></span>
        <h4>Revision delta</h4>
      </header>
      <p class="genui-revision-delta-summary__label"><%= @revision_label %></p>
      <p class="genui-revision-delta-summary__summary"><%= @summary %></p>
      <dl class="genui-revision-delta-summary__meta">
        <div :if={@baseline_label}>
          <dt>Baseline</dt>
          <dd><%= @baseline_label %></dd>
        </div>
        <div :if={@candidate_label}>
          <dt>Candidate</dt>
          <dd><%= @candidate_label %></dd>
        </div>
        <div :if={@changed_at}>
          <dt>Changed</dt>
          <dd><%= @changed_at %></dd>
        </div>
        <div :if={@changed_by}>
          <dt>Changed by</dt>
          <dd><%= @changed_by %></dd>
        </div>
      </dl>
      <section :if={@normalized_counts != []} class="genui-revision-delta-summary__counts">
        <h5>Change summary</h5>
        <ul>
          <li
            :for={count <- @normalized_counts}
            class="genui-revision-delta-summary__count"
            data-tone={count.tone}
          >
            <strong><%= count.count %></strong>
            <span><%= count.label %></span>
          </li>
        </ul>
      </section>
      <section :if={@normalized_items != []} class="genui-revision-delta-summary__items">
        <h5>Change items</h5>
        <ul>
          <li
            :for={item <- @normalized_items}
            class="genui-revision-delta-summary__item"
            data-change-id={item.change_id}
            data-disposition={item.disposition}
          >
            <div class="genui-revision-delta-summary__item-header">
              <strong><%= item.area %></strong>
              <span><%= item.disposition %></span>
              <span :if={item.impact}><%= item.impact %></span>
            </div>
            <p><%= item.summary %></p>
          </li>
        </ul>
      </section>
      <div :if={@children != []} class="genui-revision-delta-summary__children">
        <%= for child <- @children do %>
          <%= child %>
        <% end %>
      </div>
    </article>
    """
  end

  defp normalize_counts(counts) do
    counts
    |> Enum.map(&normalize_count/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_count(count) when is_map(count) do
    label = PreviewHelpers.string(count, :label)
    value = integer_value(count, :count)

    if filled?(label) and is_integer(value) do
      %{label: label, count: value, tone: PreviewHelpers.string(count, :tone)}
    end
  end

  defp normalize_count(_count), do: nil

  defp normalize_items(items) do
    items
    |> Enum.map(&normalize_item/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_item(item) when is_map(item) do
    change_id = PreviewHelpers.string(item, :change_id)
    area = PreviewHelpers.string(item, :area)
    disposition = PreviewHelpers.string(item, :disposition)
    summary = PreviewHelpers.string(item, :summary)

    if filled?(change_id) and filled?(area) and filled?(disposition) and filled?(summary) do
      %{
        change_id: change_id,
        area: area,
        disposition: disposition,
        summary: summary,
        impact: PreviewHelpers.string(item, :impact)
      }
    end
  end

  defp normalize_item(_item), do: nil

  defp integer_value(map, key) do
    case PreviewHelpers.value(map, key) do
      value when is_integer(value) -> value
      _other -> nil
    end
  end

  defp filled?(value) when is_binary(value), do: value != ""
  defp filled?(_value), do: false
end
