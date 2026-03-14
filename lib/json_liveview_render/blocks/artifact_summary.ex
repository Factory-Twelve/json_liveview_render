defmodule JsonLiveviewRender.Blocks.ArtifactSummary do
  @moduledoc """
  Internal experimental artifact summary renderer for sourcing wedge side panels.
  """

  use Phoenix.Component

  attr(:artifact_id, :string, required: true)
  attr(:artifact_type, :string, required: true)
  attr(:title, :string, required: true)
  attr(:status, :string, required: true)
  attr(:version, :string, required: true)
  attr(:generated_from_evidence_ids, :list, default: [])
  attr(:children, :list, default: [])

  def render(assigns) do
    ~H"""
    <article
      class="genui-sourcing-artifact-summary"
      data-artifact-id={@artifact_id}
      data-artifact-type={@artifact_type}
      data-status={@status}
    >
      <header class="genui-sourcing-artifact-summary__header">
        <span class="genui-sourcing-artifact-summary__type"><%= @artifact_type %></span>
        <h4><%= @title %></h4>
      </header>
      <dl class="genui-sourcing-artifact-summary__meta">
        <div>
          <dt>Status</dt>
          <dd><%= @status %></dd>
        </div>
        <div>
          <dt>Version</dt>
          <dd><%= @version %></dd>
        </div>
      </dl>
      <div
        :if={@generated_from_evidence_ids != []}
        class="genui-sourcing-artifact-summary__evidence"
      >
        <span>Generated from</span>
        <ul>
          <%= for evidence_id <- @generated_from_evidence_ids do %>
            <li><%= evidence_id %></li>
          <% end %>
        </ul>
      </div>
      <div :if={@children != []} class="genui-sourcing-artifact-summary__children">
        <%= for child <- @children do %>
          <%= child %>
        <% end %>
      </div>
    </article>
    """
  end
end
