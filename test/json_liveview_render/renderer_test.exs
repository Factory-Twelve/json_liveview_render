defmodule JsonLiveviewRender.RendererTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Bindings.Error
  alias JsonLiveviewRenderTest.Fixtures.Authorizer
  alias JsonLiveviewRenderTest.Fixtures.Catalog
  alias JsonLiveviewRenderTest.Fixtures.Registry

  test "renders valid spec with binding resolution" do
    spec = %{
      "root" => "page",
      "elements" => %{
        "page" => %{
          "type" => "column",
          "props" => %{},
          "children" => ["metric_1", "table_1"]
        },
        "metric_1" => %{
          "type" => "metric",
          "props" => %{"label" => "Revenue", "value" => "$142,300"},
          "children" => []
        },
        "table_1" => %{
          "type" => "data_table",
          "props" => %{"columns" => ["id", "amount"], "rows_binding" => "rows"},
          "children" => []
        }
      }
    }

    html =
      JsonLiveviewRender.Test.render_spec(spec, Catalog,
        registry: Registry,
        current_user: %{role: :member},
        authorizer: Authorizer,
        bindings: %{"rows" => [%{"id" => 1}, %{"id" => 2}]}
      )

    assert html =~ "Revenue"
    assert html =~ "$142,300"
    assert html =~ "rows"
    assert html =~ ">2<"
  end

  test "filters unauthorized elements" do
    spec = %{
      "root" => "page",
      "elements" => %{
        "page" => %{"type" => "row", "props" => %{}, "children" => ["metric_1", "admin_1"]},
        "metric_1" => %{
          "type" => "metric",
          "props" => %{"label" => "Revenue", "value" => "$100"},
          "children" => []
        },
        "admin_1" => %{
          "type" => "admin_panel",
          "props" => %{"title" => "Top Secret"},
          "children" => []
        }
      }
    }

    html =
      JsonLiveviewRender.Test.render_spec(spec, Catalog,
        registry: Registry,
        current_user: %{role: :member},
        authorizer: Authorizer,
        bindings: %{}
      )

    assert html =~ "Revenue"
    refute html =~ "Top Secret"
  end

  test "fails hard when registry mapping is missing" do
    defmodule PartialRegistry do
      use JsonLiveviewRender.Registry, catalog: JsonLiveviewRenderTest.Fixtures.Catalog

      alias JsonLiveviewRenderTest.Fixtures.Components

      render(:row, &Components.row/1)
      render(:metric, &Components.metric/1)
      render(:column, &Components.column/1)
      render(:section, &Components.section/1)
      render(:grid, &Components.grid/1)
    end

    spec = %{
      "root" => "page",
      "elements" => %{
        "page" => %{"type" => "row", "props" => %{}, "children" => ["admin_1"]},
        "admin_1" => %{
          "type" => "admin_panel",
          "props" => %{"title" => "Top Secret"},
          "children" => []
        }
      }
    }

    assert_raise ArgumentError, ~r/missing registry mapping/, fn ->
      JsonLiveviewRender.Test.render_spec(spec, Catalog,
        registry: PartialRegistry,
        current_user: %{role: :admin},
        authorizer: Authorizer,
        bindings: %{}
      )
    end
  end

  test "binding resolution raises when key missing" do
    spec = %{
      "root" => "table_1",
      "elements" => %{
        "table_1" => %{
          "type" => "data_table",
          "props" => %{"columns" => ["id"], "rows_binding" => "missing"},
          "children" => []
        }
      }
    }

    assert_raise Error, ~r/missing binding/, fn ->
      JsonLiveviewRender.Test.render_spec(spec, Catalog,
        registry: Registry,
        current_user: %{role: :member},
        authorizer: Authorizer,
        bindings: %{}
      )
    end
  end

  test "renderer can enforce binding type checks when enabled" do
    spec = %{
      "root" => "table_1",
      "elements" => %{
        "table_1" => %{
          "type" => "data_table",
          "props" => %{"columns" => ["id"], "rows_binding" => "rows"},
          "children" => []
        }
      }
    }

    assert_raise Error, ~r/invalid type/, fn ->
      JsonLiveviewRender.Test.render_spec(spec, Catalog,
        registry: Registry,
        current_user: %{role: :member},
        authorizer: Authorizer,
        bindings: %{"rows" => ["wrong"]},
        check_binding_types: true
      )
    end
  end
end
