defmodule JsonLiveviewRender.Blocks.ArtifactPreviewLineageSummary do
  @moduledoc """
  Internal experimental lineage summary renderer for reusable artifact preview
  panels.
  """

  use Phoenix.Component

  alias JsonLiveviewRender.Blocks.PreviewHelpers

  attr(:artifact_id, :string, required: true)
  attr(:lineage_state, :string, required: true)
  attr(:summary, :string, default: nil)
  attr(:relationships, :list, default: [])
  attr(:children, :list, default: [])

  def render(assigns) do
    assigns = Map.put(assigns, :relationship_groups, normalize_groups(assigns.relationships))

    ~H"""
    <article
      class="genui-artifact-preview-lineage-summary"
      data-artifact-id={@artifact_id}
      data-lineage-state={@lineage_state}
    >
      <header class="genui-artifact-preview-lineage-summary__header">
        <span class="genui-artifact-preview-lineage-summary__state"><%= @lineage_state %></span>
        <h4>Lineage</h4>
      </header>
      <p :if={@summary} class="genui-artifact-preview-lineage-summary__summary"><%= @summary %></p>
      <div
        :if={@relationship_groups != []}
        class="genui-artifact-preview-lineage-summary__groups"
      >
        <section
          :for={group <- @relationship_groups}
          class="genui-artifact-preview-lineage-summary__group"
        >
          <h5><%= group.label %></h5>
          <ul>
            <li
              :for={ref <- group.refs}
              class="genui-artifact-preview-lineage-summary__ref"
              data-ref-id={ref.artifact_id}
            >
              <span class="genui-artifact-preview-lineage-summary__ref-title">
                <%= ref.title || ref.artifact_id %>
              </span>
              <span
                :if={ref.title && ref.title != ref.artifact_id}
                class="genui-artifact-preview-lineage-summary__ref-id"
              >
                <%= ref.artifact_id %>
              </span>
              <span :if={ref.status} class="genui-artifact-preview-lineage-summary__ref-status">
                <%= ref.status %>
              </span>
            </li>
          </ul>
        </section>
      </div>
      <p
        :if={@relationship_groups == []}
        class="genui-artifact-preview-lineage-summary__empty"
      >
        No lineage references.
      </p>
      <div :if={@children != []} class="genui-artifact-preview-lineage-summary__children">
        <%= for child <- @children do %>
          <%= child %>
        <% end %>
      </div>
    </article>
    """
  end

  defp normalize_groups(groups) do
    groups
    |> Enum.map(&normalize_group/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_group(group) when is_map(group) do
    label = PreviewHelpers.string(group, :label)

    refs =
      group |> PreviewHelpers.list(:refs) |> Enum.map(&normalize_ref/1) |> Enum.reject(&is_nil/1)

    if is_binary(label) and label != "" and refs != [] do
      %{label: label, refs: refs}
    end
  end

  defp normalize_group(_group), do: nil

  defp normalize_ref(ref) when is_map(ref) do
    artifact_id = PreviewHelpers.string(ref, :artifact_id)

    if is_binary(artifact_id) and artifact_id != "" do
      %{
        artifact_id: artifact_id,
        title: PreviewHelpers.string(ref, :title),
        status: PreviewHelpers.string(ref, :status)
      }
    end
  end

  defp normalize_ref(_ref), do: nil
end
