defmodule JsonLiveviewRenderTest.Fixtures.Catalog do
  use JsonLiveviewRender.Catalog

  component :metric do
    description("Single KPI")
    prop(:label, :string, required: true)
    prop(:value, :string, required: true)
    prop(:trend, :enum, values: [:up, :down, :flat])
  end

  component :data_table do
    description("Simple table")
    prop(:rows_binding, :string, required: true, binding_type: {:list, :map})
    prop(:columns, {:list, :string}, required: true)
    permission(:member)
  end

  component :admin_panel do
    description("Admin-only panel")
    prop(:title, :string, required: true)
    permission(:admin)
  end
end

defmodule JsonLiveviewRenderTest.Fixtures.Components do
  use Phoenix.Component

  attr(:label, :string, required: true)
  attr(:value, :string, required: true)
  attr(:trend, :string, default: nil)

  def metric(assigns) do
    ~H"""
    <div class="metric">
      <span class="label"><%= @label %></span>
      <span class="value"><%= @value %></span>
      <span :if={@trend} class="trend"><%= @trend %></span>
    </div>
    """
  end

  attr(:rows, :list, required: true)
  attr(:columns, :list, required: true)

  def data_table(assigns) do
    ~H"""
    <div class="table">
      <span class="cols"><%= Enum.join(@columns, ",") %></span>
      <span class="rows"><%= length(@rows) %></span>
    </div>
    """
  end

  attr(:title, :string, required: true)

  def admin_panel(assigns) do
    ~H"""
    <div class="admin"><%= @title %></div>
    """
  end

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

  attr(:children, :list, default: [])

  def section(assigns) do
    ~H"""
    <section>
      <%= for child <- @children do %>
        <%= child %>
      <% end %>
    </section>
    """
  end

  attr(:children, :list, default: [])

  def grid(assigns) do
    ~H"""
    <div class="grid">
      <%= for child <- @children do %>
        <%= child %>
      <% end %>
    </div>
    """
  end
end

defmodule JsonLiveviewRenderTest.Fixtures.Registry do
  use JsonLiveviewRender.Registry, catalog: JsonLiveviewRenderTest.Fixtures.Catalog

  alias JsonLiveviewRenderTest.Fixtures.Components

  render(:metric, &Components.metric/1)
  render(:data_table, &Components.data_table/1)
  render(:admin_panel, &Components.admin_panel/1)
  render(:row, &Components.row/1)
  render(:column, &Components.column/1)
  render(:section, &Components.section/1)
  render(:grid, &Components.grid/1)
end

defmodule JsonLiveviewRenderTest.Fixtures.Authorizer do
  @behaviour JsonLiveviewRender.Authorizer

  @impl true
  def allowed?(current_user, required_role) when is_map(current_user) do
    role = Map.get(current_user, :role)
    role == required_role or role == :admin
  end
end
