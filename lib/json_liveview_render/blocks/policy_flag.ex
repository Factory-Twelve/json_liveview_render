defmodule JsonLiveviewRender.Blocks.PolicyFlag do
  @moduledoc """
  Internal experimental policy flag badge renderer for sourcing wedge side panels.
  """

  use Phoenix.Component

  attr(:code, :string, required: true)
  attr(:severity, :string, required: true)
  attr(:message, :string, required: true)

  def render(assigns) do
    ~H"""
    <div
      class="genui-sourcing-policy-flag"
      data-code={@code}
      data-severity={@severity}
    >
      <strong><%= @severity %></strong>
      <span class="genui-sourcing-policy-flag__code"><%= @code %></span>
      <span class="genui-sourcing-policy-flag__message"><%= @message %></span>
    </div>
    """
  end
end
