defmodule JsonLiveviewRender.RendererTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Bindings.Error
  alias JsonLiveviewRenderTest.Fixtures.Authorizer
  alias JsonLiveviewRenderTest.Fixtures.Catalog
  alias JsonLiveviewRenderTest.Fixtures.Registry

  @dev_tools_spec %{
    "root" => "metric_1",
    "elements" => %{
      "metric_1" => %{
        "type" => "metric",
        "props" => %{"label" => "Revenue", "value" => "$100"},
        "children" => []
      }
    }
  }

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
    html =
      JsonLiveviewRender.Test.render_spec(@dev_tools_spec, Catalog,
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
    html =
      JsonLiveviewRender.Test.render_spec_with_dev_tools_disabled(@dev_tools_spec, Catalog,
        registry: Registry,
        current_user: %{role: :member},
        authorizer: Authorizer,
        bindings: %{},
        dev_tools: true,
        dev_tools_open: true
      )

    JsonLiveviewRender.Test.assert_no_dev_tools_output(html)
  end

  test "does not render dev tools when application config is a non-boolean value" do
    original = Application.get_env(:json_liveview_render, :dev_tools_enabled, :unset)

    Enum.each(["true", "false", 1, :enabled], fn value ->
      try do
        Application.put_env(:json_liveview_render, :dev_tools_enabled, value)

        html =
          JsonLiveviewRender.Test.render_spec(@dev_tools_spec, Catalog,
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
    end)
  end

  test "force-disables dev tools even when enabled by config" do
    html =
      JsonLiveviewRender.Test.render_spec(@dev_tools_spec, Catalog,
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

  test "renders nested components with mixed permitted and denied children" do
    spec = %{
      "root" => "list_1",
      "elements" => %{
        "list_1" => %{
          "type" => "card_list",
          "props" => %{"title" => "User Directory"},
          "children" => ["user_1", "user_2", "admin_card_1"]
        },
        "user_1" => %{
          "type" => "user_card",
          "props" => %{"name" => "Alice", "role" => "member"},
          "children" => []
        },
        "user_2" => %{
          "type" => "user_card",
          "props" => %{"name" => "Bob", "role" => "member"},
          "children" => []
        },
        "admin_card_1" => %{
          "type" => "privileged_card",
          "props" => %{"content" => "Admin Secret"},
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

    # Permitted children should be rendered
    assert html =~ "User Directory"
    assert html =~ "Alice"
    assert html =~ "Bob"
    assert html =~ "member"

    # Denied admin content should be filtered out
    refute html =~ "Admin Secret"
    refute html =~ "Privileged:"
  end

  test "preserves child rendering order after permission filtering" do
    spec = %{
      "root" => "container_1",
      "elements" => %{
        "container_1" => %{
          "type" => "column",
          "props" => %{},
          "children" => ["metric_1", "admin_1", "metric_2", "admin_2", "metric_3"]
        },
        "metric_1" => %{
          "type" => "metric",
          "props" => %{"label" => "First", "value" => "1"},
          "children" => []
        },
        "admin_1" => %{
          "type" => "admin_panel",
          "props" => %{"title" => "Admin Panel 1"},
          "children" => []
        },
        "metric_2" => %{
          "type" => "metric",
          "props" => %{"label" => "Second", "value" => "2"},
          "children" => []
        },
        "admin_2" => %{
          "type" => "admin_panel",
          "props" => %{"title" => "Admin Panel 2"},
          "children" => []
        },
        "metric_3" => %{
          "type" => "metric",
          "props" => %{"label" => "Third", "value" => "3"},
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

    # Verify permitted elements appear in original order
    first_pos = :binary.match(html, "First") |> elem(0)
    second_pos = :binary.match(html, "Second") |> elem(0)
    third_pos = :binary.match(html, "Third") |> elem(0)

    # Check relative order is preserved
    assert first_pos < second_pos, "First should appear before Second"
    assert second_pos < third_pos, "Second should appear before Third"

    # Verify admin content is filtered out
    refute String.contains?(html, "Admin Panel")
  end

  test "handles deeply nested component hierarchy with permissions" do
    spec = %{
      "root" => "page_1",
      "elements" => %{
        "page_1" => %{
          "type" => "section",
          "props" => %{},
          "children" => ["list_1"]
        },
        "list_1" => %{
          "type" => "card_list",
          "props" => %{"title" => "Teams"},
          "children" => ["user_1", "nested_admin_1"]
        },
        "user_1" => %{
          "type" => "user_card",
          "props" => %{"name" => "Charlie", "role" => "lead"},
          "children" => []
        },
        "nested_admin_1" => %{
          "type" => "privileged_card",
          "props" => %{"content" => "Sensitive Data"},
          "children" => []
        }
      }
    }

    # Test as member - should see user but not admin content
    member_html =
      JsonLiveviewRender.Test.render_spec(spec, Catalog,
        registry: Registry,
        current_user: %{role: :member},
        authorizer: Authorizer,
        bindings: %{}
      )

    assert member_html =~ "Teams"
    assert member_html =~ "Charlie"
    refute member_html =~ "Sensitive Data"

    # Test as admin - should see everything
    admin_html =
      JsonLiveviewRender.Test.render_spec(spec, Catalog,
        registry: Registry,
        current_user: %{role: :admin},
        authorizer: Authorizer,
        bindings: %{}
      )

    assert admin_html =~ "Teams"
    assert admin_html =~ "Charlie"
    assert admin_html =~ "Sensitive Data"
    assert admin_html =~ "Privileged:"
  end

  test "missing slot definitions produce empty render path instead of crashing" do
    # Test component with no children field defined
    spec_no_children = %{
      "root" => "metric_1",
      "elements" => %{
        "metric_1" => %{
          "type" => "metric",
          "props" => %{"label" => "Revenue", "value" => "$100"}
          # Note: no "children" field defined
        }
      }
    }

    html =
      JsonLiveviewRender.Test.render_spec(spec_no_children, Catalog,
        registry: Registry,
        current_user: %{role: :member},
        authorizer: Authorizer,
        bindings: %{}
      )

    assert html =~ "Revenue"
    assert html =~ "$100"

    # Test component that could accept children but has empty children array
    spec_empty_children = %{
      "root" => "container_1",
      "elements" => %{
        "container_1" => %{
          "type" => "column",
          "props" => %{},
          "children" => []
        }
      }
    }

    html =
      JsonLiveviewRender.Test.render_spec(spec_empty_children, Catalog,
        registry: Registry,
        current_user: %{role: :member},
        authorizer: Authorizer,
        bindings: %{}
      )

    assert html =~ ~s(class="column")
  end

  test "slot payload is always a list structure for deterministic rendering" do
    # Use a custom registry to test the assigns passed to components
    defmodule AssignCapturingRegistry do
      use JsonLiveviewRender.Registry, catalog: JsonLiveviewRenderTest.Fixtures.Catalog

      alias JsonLiveviewRenderTest.Fixtures.Components

      # Capture assigns for inspection
      defmodule AssignCapturer do
        use Phoenix.Component

        def column(assigns) do
          # Send assigns to test process for inspection
          send(self(), {:captured_assigns, assigns})
          Components.column(assigns)
        end
      end

      render(:column, &AssignCapturer.column/1)
      render(:metric, &Components.metric/1)
    end

    spec = %{
      "root" => "container_1",
      "elements" => %{
        "container_1" => %{
          "type" => "column",
          "props" => %{},
          "children" => ["metric_1"]
        },
        "metric_1" => %{
          "type" => "metric",
          "props" => %{"label" => "Test", "value" => "123"},
          "children" => []
        }
      }
    }

    JsonLiveviewRender.Test.render_spec(spec, Catalog,
      registry: AssignCapturingRegistry,
      current_user: %{role: :member},
      authorizer: Authorizer,
      bindings: %{}
    )

    # Verify that children is always a list
    assert_received {:captured_assigns, assigns}
    assert Map.has_key?(assigns, :children)
    assert is_list(assigns.children)
    assert length(assigns.children) == 1
  end
end
