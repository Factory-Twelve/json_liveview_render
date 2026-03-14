defmodule JsonLiveviewRender.Blocks.ArtifactPreviewHeader do
  @moduledoc """
  Internal experimental artifact preview header renderer for reusable detail
  panels.
  """

  use Phoenix.Component

  attr(:artifact_id, :string, required: true)
  attr(:artifact_type, :string, required: true)
  attr(:title, :string, required: true)
  attr(:status, :string, required: true)
  attr(:version, :string, required: true)
  attr(:summary, :string, default: nil)
  attr(:owner, :string, default: nil)
  attr(:updated_at, :string, default: nil)
  attr(:children, :list, default: [])

  def render(assigns) do
    ~H"""
    <article
      class="genui-artifact-preview-header"
      data-artifact-id={@artifact_id}
      data-artifact-type={@artifact_type}
      data-status={@status}
    >
      <header class="genui-artifact-preview-header__header">
        <span class="genui-artifact-preview-header__type"><%= @artifact_type %></span>
        <h4><%= @title %></h4>
      </header>
      <p :if={@summary} class="genui-artifact-preview-header__summary"><%= @summary %></p>
      <dl class="genui-artifact-preview-header__meta">
        <div>
          <dt>Status</dt>
          <dd><%= @status %></dd>
        </div>
        <div>
          <dt>Version</dt>
          <dd><%= @version %></dd>
        </div>
        <div :if={@owner}>
          <dt>Owner</dt>
          <dd><%= @owner %></dd>
        </div>
        <div :if={@updated_at}>
          <dt>Updated</dt>
          <dd><%= @updated_at %></dd>
        </div>
      </dl>
      <div :if={@children != []} class="genui-artifact-preview-header__children">
        <%= for child <- @children do %>
          <%= child %>
        <% end %>
      </div>
    </article>
    """
  end
end
