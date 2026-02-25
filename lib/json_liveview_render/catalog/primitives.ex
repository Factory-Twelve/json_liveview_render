defmodule JsonLiveviewRender.Catalog.Primitives do
  @moduledoc "Built-in layout primitives that can be merged into a catalog."

  alias JsonLiveviewRender.Catalog.ComponentDef
  alias JsonLiveviewRender.Catalog.PropDef

  @spec components() :: %{optional(atom()) => ComponentDef.t()}
  def components do
    %{
      row: %ComponentDef{
        name: :row,
        description: "Horizontal layout container",
        slots: [:default],
        props: %{
          gap: %PropDef{name: :gap, type: :enum, values: [:sm, :md, :lg], default: :md}
        }
      },
      column: %ComponentDef{
        name: :column,
        description: "Vertical layout container",
        slots: [:default],
        props: %{
          gap: %PropDef{name: :gap, type: :enum, values: [:sm, :md, :lg], default: :md}
        }
      },
      section: %ComponentDef{
        name: :section,
        description: "Titled content section with optional collapse",
        slots: [:default],
        props: %{
          title: %PropDef{name: :title, type: :string, required: true},
          collapsible: %PropDef{name: :collapsible, type: :boolean, default: false},
          collapsed: %PropDef{name: :collapsed, type: :boolean, default: false}
        }
      },
      grid: %ComponentDef{
        name: :grid,
        description: "Grid layout container",
        slots: [:default],
        props: %{
          columns: %PropDef{name: :columns, type: :integer, default: 12},
          gap: %PropDef{name: :gap, type: :enum, values: [:sm, :md, :lg], default: :md}
        }
      }
    }
  end
end
