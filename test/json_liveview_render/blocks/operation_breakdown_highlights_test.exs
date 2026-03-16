defmodule JsonLiveviewRender.Blocks.OperationBreakdownHighlightsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonLiveviewRender.Blocks.OperationBreakdownHighlights

  test "renders operation highlights, smv totals, and flags" do
    html =
      render_component(&OperationBreakdownHighlights.render/1,
        operation_breakdown_id: "operation_breakdown_peak_hanoi_pp",
        breakdown_label: "Peak Hanoi PP route",
        status: "review",
        summary:
          "The sewing path is stable, but pressing and pack-out remain the main SMV and cost-share watchpoints.",
        supplier_label: "Peak Textiles",
        facility_label: "Peak Hanoi",
        total_operations: 18,
        total_smv: 24.8,
        manual_share_pct: 81.0,
        highlights: [
          %{
            "operation_key" => "op_press_finish",
            "label" => "Press and finish",
            "workstation" => "finishing",
            "change_type" => "watch",
            "smv" => 2.8,
            "cost_share_pct" => 11.3,
            "summary" => "Wrinkle recovery rework keeps the finish step above plan."
          }
        ],
        flags: [
          %{
            "code" => "packout_manual_dependency",
            "severity" => "medium",
            "message" => "Pack-out still depends on a manual fold-and-bag station."
          }
        ]
      )

    assert html =~ "Operation breakdown"
    assert html =~ "Peak Hanoi PP route"
    assert html =~ "Peak Textiles"
    assert html =~ "24.8"
    assert html =~ "81%"
    assert html =~ "Press and finish"
    assert html =~ "finishing"
    assert html =~ "11.3%"
    assert html =~ "packout_manual_dependency"
  end

  test "drops malformed highlights and flags" do
    html =
      render_component(&OperationBreakdownHighlights.render/1,
        operation_breakdown_id: "operation_breakdown_peak_hanoi_pp",
        breakdown_label: "Peak Hanoi PP route",
        status: "review",
        summary: "Summary",
        highlights: [
          %{"operation_key" => "op_press_finish", "label" => "Press and finish"},
          %{"operation_key" => "broken_highlight"}
        ],
        flags: [
          %{
            "code" => "packout_manual_dependency",
            "severity" => "medium",
            "message" => "Pack-out still depends on a manual fold-and-bag station."
          },
          %{"code" => "broken_flag", "severity" => "high"}
        ]
      )

    assert html =~ "Press and finish"
    refute html =~ "broken_highlight"
    assert html =~ "packout_manual_dependency"
    refute html =~ "broken_flag"
  end
end
