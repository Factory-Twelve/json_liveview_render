defmodule JsonLiveviewRender.Blocks.Layout do
  @moduledoc """
  Internal experimental layout renderers used by the sourcing block bundle.
  """

  use Phoenix.Component

  attr(:gap, :any, default: "md")
  attr(:children, :list, default: [])

  def row(assigns) do
    ~H"""
    <div class="genui-block-row" data-gap={to_string(@gap)}>
      <%= for child <- @children do %>
        <%= child %>
      <% end %>
    </div>
    """
  end

  attr(:gap, :any, default: "md")
  attr(:children, :list, default: [])

  def column(assigns) do
    ~H"""
    <div class="genui-block-column" data-gap={to_string(@gap)}>
      <%= for child <- @children do %>
        <%= child %>
      <% end %>
    </div>
    """
  end

  attr(:title, :string, required: true)
  attr(:collapsible, :boolean, default: false)
  attr(:collapsed, :boolean, default: false)
  attr(:children, :list, default: [])

  def section(assigns) do
    ~H"""
    <section
      class="genui-block-section"
      data-collapsible={@collapsible}
      data-collapsed={@collapsed}
    >
      <header class="genui-block-section__header">
        <h3><%= @title %></h3>
      </header>
      <div :if={!@collapsed} class="genui-block-section__body">
        <%= for child <- @children do %>
          <%= child %>
        <% end %>
      </div>
    </section>
    """
  end

  attr(:columns, :integer, default: 12)
  attr(:gap, :any, default: "md")
  attr(:children, :list, default: [])

  def grid(assigns) do
    ~H"""
    <div class="genui-block-grid" data-columns={@columns} data-gap={to_string(@gap)}>
      <%= for child <- @children do %>
        <%= child %>
      <% end %>
    </div>
    """
  end
end
