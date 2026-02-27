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

  test "partial specs fail by default when unresolved refs exist" do
    spec = %{
      "root" => "page",
      "elements" => %{
        "page" => %{"type" => "row", "props" => %{}, "children" => ["metric_1", "missing_1"]},
        "metric_1" => %{
          "type" => "metric",
          "props" => %{"label" => "Revenue", "value" => "$100"},
          "children" => []
        }
      }
    }

    assert_raise ArgumentError, ~r/invalid JsonLiveviewRender spec/, fn ->
      JsonLiveviewRender.Test.render_spec(spec, Catalog,
        registry: Registry,
        current_user: %{role: :member},
        authorizer: Authorizer,
        bindings: %{}
      )
    end
  end

  test "partial specs can render available elements when allow_partial is true" do
    spec = %{
      "root" => "page",
      "elements" => %{
        "page" => %{"type" => "row", "props" => %{}, "children" => ["metric_1", "missing_1"]},
        "metric_1" => %{
          "type" => "metric",
          "props" => %{"label" => "Revenue", "value" => "$100"},
          "children" => []
        }
      }
    }

    html =
      JsonLiveviewRender.Test.render_spec(spec, Catalog,
        registry: Registry,
        current_user: %{role: :member},
        authorizer: Authorizer,
        bindings: %{},
        allow_partial: true
      )

    assert html =~ "Revenue"
    assert html =~ "$100"
  end

  test "renders dev tools inspector when enabled" do
    spec = %{
      "root" => "metric_1",
      "elements" => %{
        "metric_1" => %{
          "type" => "metric",
          "props" => %{"label" => "Revenue", "value" => "$100"},
          "children" => []
        }
      }
    }

    html =
      JsonLiveviewRender.Test.render_spec(spec, Catalog,
        registry: Registry,
        current_user: %{role: :member},
        authorizer: Authorizer,
        bindings: %{},
        dev_tools: true,
        dev_tools_open: true,
        dev_tools_enabled: true
      )

    assert html =~ "data-json-liveview-render-devtools"
    assert html =~ "Input Spec"
    assert html =~ "Rendered Spec"
  end

  test "does not render dev tools in production-like guard mode" do
    spec = %{
      "root" => "metric_1",
      "elements" => %{
        "metric_1" => %{
          "type" => "metric",
          "props" => %{"label" => "Revenue", "value" => "$100"},
          "children" => []
        }
      }
    }

    html =
      JsonLiveviewRender.Test.render_spec_in_production_env(spec, Catalog,
        registry: Registry,
        current_user: %{role: :member},
        authorizer: Authorizer,
        bindings: %{},
        dev_tools: true,
        dev_tools_open: true
      )

    JsonLiveviewRender.Test.assert_no_dev_tools_output(html)
  end

  test "does not render dev tools when application config is a non-boolean string" do
    spec = %{
      "root" => "metric_1",
      "elements" => %{
        "metric_1" => %{
          "type" => "metric",
          "props" => %{"label" => "Revenue", "value" => "$100"},
          "children" => []
        }
      }
    }

    original = Application.get_env(:json_liveview_render, :dev_tools_enabled, :unset)

    try do
      Application.put_env(:json_liveview_render, :dev_tools_enabled, "false")

      html =
        JsonLiveviewRender.Test.render_spec(spec, Catalog,
          registry: Registry,
          current_user: %{role: :member},
          authorizer: Authorizer,
          bindings: %{},
          dev_tools: true,
          dev_tools_open: true
        )

      JsonLiveviewRender.Test.assert_no_dev_tools_output(html)
    after
      if original == :unset do
        Application.delete_env(:json_liveview_render, :dev_tools_enabled)
      else
        Application.put_env(:json_liveview_render, :dev_tools_enabled, original)
      end
    end
  end

  test "force-disables dev tools even when enabled by config" do
    spec = %{
      "root" => "metric_1",
      "elements" => %{
        "metric_1" => %{
          "type" => "metric",
          "props" => %{"label" => "Revenue", "value" => "$100"},
          "children" => []
        }
      }
    }

    html =
      JsonLiveviewRender.Test.render_spec(spec, Catalog,
        registry: Registry,
        current_user: %{role: :member},
        authorizer: Authorizer,
        bindings: %{},
        dev_tools: true,
        dev_tools_enabled: true,
        dev_tools_force_disable: true,
        dev_tools_open: true
      )

    JsonLiveviewRender.Test.assert_no_dev_tools_output(html)
  end

  test "renderer module does not keep an unused DevTools alias" do
    source = File.read!(Path.expand("../../lib/json_liveview_render/renderer.ex", __DIR__))

    refute String.contains?(source, "alias JsonLiveviewRender.DevTools")
  end
end
