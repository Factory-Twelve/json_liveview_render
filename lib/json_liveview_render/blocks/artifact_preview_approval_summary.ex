defmodule JsonLiveviewRender.Blocks.ArtifactPreviewApprovalSummary do
  @moduledoc """
  Internal experimental approval summary renderer for reusable artifact preview
  panels.
  """

  use Phoenix.Component

  alias JsonLiveviewRender.Blocks.PreviewHelpers

  attr(:artifact_id, :string, required: true)
  attr(:overall_state, :string, required: true)
  attr(:requested_at, :string, default: nil)
  attr(:decided_at, :string, default: nil)
  attr(:summary, :string, default: nil)
  attr(:reviewers, :list, default: [])
  attr(:children, :list, default: [])

  def render(assigns) do
    assigns = Map.put(assigns, :normalized_reviewers, normalize_reviewers(assigns.reviewers))

    ~H"""
    <article
      class="genui-artifact-preview-approval-summary"
      data-artifact-id={@artifact_id}
      data-overall-state={@overall_state}
    >
      <header class="genui-artifact-preview-approval-summary__header">
        <span class="genui-artifact-preview-approval-summary__state"><%= @overall_state %></span>
        <h4>Approval</h4>
      </header>
      <p :if={@summary} class="genui-artifact-preview-approval-summary__summary"><%= @summary %></p>
      <dl class="genui-artifact-preview-approval-summary__meta">
        <div :if={@requested_at}>
          <dt>Requested</dt>
          <dd><%= @requested_at %></dd>
        </div>
        <div :if={@decided_at}>
          <dt>Decided</dt>
          <dd><%= @decided_at %></dd>
        </div>
      </dl>
      <ul
        :if={@normalized_reviewers != []}
        class="genui-artifact-preview-approval-summary__reviewers"
      >
        <li
          :for={reviewer <- @normalized_reviewers}
          class="genui-artifact-preview-approval-summary__reviewer"
          data-reviewer-status={reviewer.status}
        >
          <div class="genui-artifact-preview-approval-summary__reviewer-header">
            <strong><%= reviewer.name %></strong>
            <span><%= reviewer.status %></span>
          </div>
          <p :if={reviewer.role} class="genui-artifact-preview-approval-summary__reviewer-role">
            <%= reviewer.role %>
          </p>
          <p
            :if={reviewer.decided_at}
            class="genui-artifact-preview-approval-summary__reviewer-decided-at"
          >
            <%= reviewer.decided_at %>
          </p>
          <p :if={reviewer.note} class="genui-artifact-preview-approval-summary__reviewer-note">
            <%= reviewer.note %>
          </p>
        </li>
      </ul>
      <p
        :if={@normalized_reviewers == []}
        class="genui-artifact-preview-approval-summary__empty"
      >
        No reviewers assigned.
      </p>
      <div :if={@children != []} class="genui-artifact-preview-approval-summary__children">
        <%= for child <- @children do %>
          <%= child %>
        <% end %>
      </div>
    </article>
    """
  end

  defp normalize_reviewers(reviewers) do
    reviewers
    |> Enum.map(&normalize_reviewer/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_reviewer(reviewer) when is_map(reviewer) do
    name = PreviewHelpers.string(reviewer, :name)
    status = PreviewHelpers.string(reviewer, :status)

    if is_binary(name) and name != "" and is_binary(status) and status != "" do
      %{
        name: name,
        status: status,
        role: PreviewHelpers.string(reviewer, :role),
        decided_at: PreviewHelpers.string(reviewer, :decided_at),
        note: PreviewHelpers.string(reviewer, :note)
      }
    end
  end

  defp normalize_reviewer(_reviewer), do: nil
end
