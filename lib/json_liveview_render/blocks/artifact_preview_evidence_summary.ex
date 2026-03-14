defmodule JsonLiveviewRender.Blocks.ArtifactPreviewEvidenceSummary do
  @moduledoc """
  Internal experimental evidence summary renderer for reusable artifact preview
  panels.
  """

  use Phoenix.Component

  alias JsonLiveviewRender.Blocks.PreviewHelpers

  attr(:artifact_id, :string, required: true)
  attr(:total_count, :integer, required: true)
  attr(:latest_captured_at, :string, default: nil)
  attr(:summary, :string, default: nil)
  attr(:source_breakdown, :list, default: [])
  attr(:evidence_refs, :list, default: [])
  attr(:children, :list, default: [])

  def render(assigns) do
    assigns =
      assigns
      |> Map.put(:normalized_breakdown, normalize_breakdown(assigns.source_breakdown))
      |> Map.put(:normalized_refs, normalize_refs(assigns.evidence_refs))

    ~H"""
    <article
      class="genui-artifact-preview-evidence-summary"
      data-artifact-id={@artifact_id}
      data-total-count={@total_count}
    >
      <header class="genui-artifact-preview-evidence-summary__header">
        <span class="genui-artifact-preview-evidence-summary__count"><%= @total_count %></span>
        <h4>Evidence</h4>
      </header>
      <p :if={@summary} class="genui-artifact-preview-evidence-summary__summary"><%= @summary %></p>
      <dl class="genui-artifact-preview-evidence-summary__meta">
        <div>
          <dt>Total refs</dt>
          <dd><%= @total_count %></dd>
        </div>
        <div :if={@latest_captured_at}>
          <dt>Latest captured</dt>
          <dd><%= @latest_captured_at %></dd>
        </div>
      </dl>
      <ul
        :if={@normalized_breakdown != []}
        class="genui-artifact-preview-evidence-summary__breakdown"
      >
        <li :for={source <- @normalized_breakdown}>
          <span><%= source.label %></span>
          <strong><%= source.count %></strong>
        </li>
      </ul>
      <ul :if={@normalized_refs != []} class="genui-artifact-preview-evidence-summary__refs">
        <li
          :for={ref <- @normalized_refs}
          class="genui-artifact-preview-evidence-summary__ref"
          data-ref-id={ref.ref_id}
        >
          <div class="genui-artifact-preview-evidence-summary__ref-header">
            <strong><%= ref.title %></strong>
            <span :if={ref.source_type}><%= ref.source_type %></span>
          </div>
          <p :if={ref.captured_at} class="genui-artifact-preview-evidence-summary__ref-captured-at">
            <%= ref.captured_at %>
          </p>
          <a :if={ref.uri} href={ref.uri} rel="noreferrer" target="_blank">
            <%= ref.uri %>
          </a>
        </li>
      </ul>
      <p
        :if={@normalized_refs == []}
        class="genui-artifact-preview-evidence-summary__empty"
      >
        No evidence references.
      </p>
      <div :if={@children != []} class="genui-artifact-preview-evidence-summary__children">
        <%= for child <- @children do %>
          <%= child %>
        <% end %>
      </div>
    </article>
    """
  end

  defp normalize_breakdown(breakdown) do
    breakdown
    |> Enum.map(&normalize_source/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_source(source) when is_map(source) do
    label = PreviewHelpers.string(source, :label)
    count = PreviewHelpers.integer(source, :count)

    if is_binary(label) and label != "" do
      %{label: label, count: count}
    end
  end

  defp normalize_source(_source), do: nil

  defp normalize_refs(refs) do
    refs
    |> Enum.map(&normalize_ref/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_ref(ref) when is_map(ref) do
    ref_id = PreviewHelpers.string(ref, :ref_id)
    title = PreviewHelpers.string(ref, :title)

    if is_binary(ref_id) and ref_id != "" and is_binary(title) and title != "" do
      %{
        ref_id: ref_id,
        title: title,
        source_type: PreviewHelpers.string(ref, :source_type),
        captured_at: PreviewHelpers.string(ref, :captured_at),
        uri: PreviewHelpers.string(ref, :uri)
      }
    end
  end

  defp normalize_ref(_ref), do: nil
end
