defmodule JsonLiveviewRender.Blocks.ApprovalWidget do
  @moduledoc """
  Internal experimental approval widget renderer for sourcing wedge side panels.
  """

  use Phoenix.Component

  attr(:approval_id, :string, required: true)
  attr(:subject_id, :string, required: true)
  attr(:decision, :string, required: true)
  attr(:actor, :string, required: true)
  attr(:decided_at, :string, required: true)
  attr(:rationale, :string, default: nil)
  attr(:read_only, :boolean, default: false)
  attr(:disabled_reason, :string, default: nil)
  attr(:children, :list, default: [])

  def render(assigns) do
    ~H"""
    <article
      class="genui-sourcing-approval-widget"
      data-approval-id={@approval_id}
      data-subject-id={@subject_id}
      data-decision={@decision}
    >
      <header class="genui-sourcing-approval-widget__header">
        <span class="genui-sourcing-approval-widget__decision"><%= @decision %></span>
        <h4>Approval</h4>
      </header>
      <dl class="genui-sourcing-approval-widget__meta">
        <div>
          <dt>Subject</dt>
          <dd><%= @subject_id %></dd>
        </div>
        <div>
          <dt>Actor</dt>
          <dd><%= @actor %></dd>
        </div>
        <div>
          <dt>Decided at</dt>
          <dd><%= @decided_at %></dd>
        </div>
      </dl>
      <p :if={@rationale} class="genui-sourcing-approval-widget__rationale"><%= @rationale %></p>
      <p :if={@read_only} class="genui-sourcing-approval-widget__state">Read only</p>
      <p :if={@disabled_reason} class="genui-sourcing-approval-widget__disabled-reason">
        <%= @disabled_reason %>
      </p>
      <div :if={@children != []} class="genui-sourcing-approval-widget__children">
        <%= for child <- @children do %>
          <%= child %>
        <% end %>
      </div>
    </article>
    """
  end
end
