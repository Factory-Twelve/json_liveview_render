defmodule JsonLiveviewRender.RendererErrorBoundaryTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias JsonLiveviewRenderTest.Fixtures.Catalog
  alias JsonLiveviewRenderTest.Fixtures.Registry
  alias JsonLiveviewRenderTest.Fixtures.Authorizer

  describe "error_boundary: true" do
    test "catches missing registry mapping and renders nil" do
      defmodule PartialRegistryEB do
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

      log =
        capture_log(fn ->
          html =
            JsonLiveviewRender.Test.render_spec(spec, Catalog,
              registry: PartialRegistryEB,
              current_user: %{role: :admin},
              authorizer: Authorizer,
              bindings: %{},
              error_boundary: true
            )

          # The row renders but the admin_panel child is swallowed
          assert html =~ ~s(class="row")
          refute html =~ "Top Secret"
        end)

      assert log =~ "error boundary caught error"
    end

    test "catches binding resolution errors" do
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

      log =
        capture_log(fn ->
          html =
            JsonLiveviewRender.Test.render_spec(spec, Catalog,
              registry: Registry,
              current_user: %{role: :member},
              authorizer: Authorizer,
              bindings: %{},
              error_boundary: true
            )

          # Element disappears instead of crashing
          refute html =~ "table"
        end)

      assert log =~ "error boundary caught error"
    end

    test "catches callback crash" do
      defmodule CrashingRegistry do
        use JsonLiveviewRender.Registry, catalog: JsonLiveviewRenderTest.Fixtures.Catalog

        alias JsonLiveviewRenderTest.Fixtures.Components

        render(:row, &Components.row/1)
        render(:column, &Components.column/1)
        render(:section, &Components.section/1)
        render(:grid, &Components.grid/1)

        render(:metric, fn _assigns ->
          raise "boom from metric callback"
        end)
      end

      spec = %{
        "root" => "metric_1",
        "elements" => %{
          "metric_1" => %{
            "type" => "metric",
            "props" => %{"label" => "Rev", "value" => "$1"},
            "children" => []
          }
        }
      }

      log =
        capture_log(fn ->
          html =
            JsonLiveviewRender.Test.render_spec(spec, Catalog,
              registry: CrashingRegistry,
              current_user: %{role: :member},
              authorizer: Authorizer,
              bindings: %{},
              error_boundary: true
            )

          refute html =~ "Rev"
        end)

      assert log =~ "error boundary caught error"
      assert log =~ "boom from metric callback"
    end

    test "siblings survive when one element errors" do
      defmodule SiblingRegistry do
        use JsonLiveviewRender.Registry, catalog: JsonLiveviewRenderTest.Fixtures.Catalog

        alias JsonLiveviewRenderTest.Fixtures.Components

        render(:row, &Components.row/1)
        render(:column, &Components.column/1)
        render(:section, &Components.section/1)
        render(:grid, &Components.grid/1)
        render(:data_table, &Components.data_table/1)
        render(:admin_panel, &Components.admin_panel/1)
        render(:card_list, &Components.card_list/1)
        render(:user_card, &Components.user_card/1)
        render(:privileged_card, &Components.privileged_card/1)

        render(:metric, fn _assigns ->
          raise "metric crash"
        end)
      end

      spec = %{
        "root" => "page",
        "elements" => %{
          "page" => %{
            "type" => "row",
            "props" => %{},
            "children" => ["metric_1", "admin_1"]
          },
          "metric_1" => %{
            "type" => "metric",
            "props" => %{"label" => "Rev", "value" => "$1"},
            "children" => []
          },
          "admin_1" => %{
            "type" => "admin_panel",
            "props" => %{"title" => "Works"},
            "children" => []
          }
        }
      }

      capture_log(fn ->
        html =
          JsonLiveviewRender.Test.render_spec(spec, Catalog,
            registry: SiblingRegistry,
            current_user: %{role: :admin},
            authorizer: Authorizer,
            bindings: %{},
            error_boundary: true
          )

        # Crashing metric disappears but admin_panel sibling survives
        refute html =~ "Rev"
        assert html =~ "Works"
      end)
    end

    test "nested child error does not crash parent" do
      defmodule NestedRegistry do
        use JsonLiveviewRender.Registry, catalog: JsonLiveviewRenderTest.Fixtures.Catalog

        alias JsonLiveviewRenderTest.Fixtures.Components

        render(:row, &Components.row/1)
        render(:column, &Components.column/1)
        render(:section, &Components.section/1)
        render(:grid, &Components.grid/1)
        render(:data_table, &Components.data_table/1)
        render(:admin_panel, &Components.admin_panel/1)
        render(:card_list, &Components.card_list/1)
        render(:user_card, &Components.user_card/1)
        render(:privileged_card, &Components.privileged_card/1)

        render(:metric, fn _assigns ->
          raise "nested metric crash"
        end)
      end

      spec = %{
        "root" => "page",
        "elements" => %{
          "page" => %{
            "type" => "column",
            "props" => %{},
            "children" => ["metric_1"]
          },
          "metric_1" => %{
            "type" => "metric",
            "props" => %{"label" => "Rev", "value" => "$1"},
            "children" => []
          }
        }
      }

      capture_log(fn ->
        html =
          JsonLiveviewRender.Test.render_spec(spec, Catalog,
            registry: NestedRegistry,
            current_user: %{role: :member},
            authorizer: Authorizer,
            bindings: %{},
            error_boundary: true
          )

        # Parent column still renders, child metric is removed
        assert html =~ ~s(class="column")
        refute html =~ "Rev"
      end)
    end
  end

  describe "error_boundary: false (default)" do
    test "missing registry mapping still raises" do
      defmodule PartialRegistryNoEB do
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
          registry: PartialRegistryNoEB,
          current_user: %{role: :admin},
          authorizer: Authorizer,
          bindings: %{}
        )
      end
    end
  end
end
