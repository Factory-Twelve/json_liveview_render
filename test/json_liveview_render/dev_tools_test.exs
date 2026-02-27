defmodule JsonLiveviewRender.DevToolsTest do
  use ExUnit.Case, async: true

  require Phoenix.LiveViewTest

  alias JsonLiveviewRender.DevTools
  alias JsonLiveviewRenderTest.Fixtures.Catalog

  test "shows validation status and errors for invalid input specs" do
    invalid_input = %{
      "root" => "missing_root",
      "elements" => %{
        "metric_1" => %{"type" => "metric", "props" => %{"label" => "A", "value" => "1"}}
      }
    }

    render_spec = %{
      "root" => "metric_1",
      "elements" => %{
        "metric_1" => %{
          "type" => "metric",
          "props" => %{"label" => "A", "value" => "1"},
          "children" => []
        }
      }
    }

    html =
      Phoenix.LiveViewTest.render_component(&DevTools.render/1,
        input_spec: invalid_input,
        render_spec: render_spec,
        catalog: Catalog,
        strict: true
      )

    assert html =~ "input_status=error"
    assert html =~ "render_status=ok"
    assert html =~ "data-json-liveview-render-input-errors"
  end
end
