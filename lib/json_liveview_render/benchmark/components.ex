defmodule JsonLiveviewRender.Benchmark.Components do
  use Phoenix.Component

  attr(:children, :list, default: [])

  def row(assigns) do
    ~H"""
    <div class="row">
      <%= for child <- @children do %>
        <%= child %>
      <% end %>
    </div>
    """
  end

  attr(:children, :list, default: [])

  def column(assigns) do
    ~H"""
    <div class="column">
      <%= for child <- @children do %>
        <%= child %>
      <% end %>
    </div>
    """
  end

  attr(:label, :string, required: true)
  attr(:value, :string, required: true)

  def metric(assigns) do
    ~H"""
    <p>
      <span class="label"><%= @label %></span>
      <span class="value"><%= @value %></span>
    </p>
    """
  end

  attr(:title, :string, required: true)
  attr(:children, :list, default: [])

  def section_metric_card(assigns) do
    ~H"""
    <article class="section_metric_card">
      <h3><%= @title %></h3>
      <%= for child <- @children do %>
        <%= child %>
      <% end %>
    </article>
    """
  end
end
