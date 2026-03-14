defmodule JsonLiveviewRender.Blocks.ApprovalAction do
  @moduledoc """
  Internal experimental approval action renderer for sourcing wedge side panels.
  """

  use Phoenix.Component

  attr(:action_id, :string, required: true)
  attr(:label, :string, required: true)
  attr(:tone, :string, default: "secondary")
  attr(:disabled, :boolean, default: false)
  attr(:disabled_reason, :string, default: nil)

  def render(assigns) do
    ~H"""
    <div class="genui-sourcing-approval-action" data-action-id={@action_id} data-tone={@tone}>
      <button type="button" disabled={@disabled}>
        <%= @label %>
      </button>
      <p :if={@disabled_reason} class="genui-sourcing-approval-action__reason">
        <%= @disabled_reason %>
      </p>
    </div>
    """
  end
end
