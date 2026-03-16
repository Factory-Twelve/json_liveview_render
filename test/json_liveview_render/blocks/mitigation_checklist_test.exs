defmodule JsonLiveviewRender.Blocks.MitigationChecklistTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonLiveviewRender.Blocks.MitigationChecklist

  test "renders blocking and conditional mitigation items" do
    html =
      render_component(&MitigationChecklist.render/1,
        checklist_id: "mitigation_feasibility_alpine",
        summary: "Separate hard blocks from conditional follow-through work.",
        items: [
          %{
            "item_id" => "requote_tariff_exposure",
            "label" => "Re-quote landed cost with tariff delta",
            "status" => "required",
            "blocking" => true,
            "severity" => "high",
            "summary" => "Decision cannot move forward until landed cost is restated.",
            "owner" => "Merch ops",
            "due_at" => "2026-03-18"
          },
          %{
            "item_id" => "hold_backup_capacity",
            "label" => "Hold Lotus Da Nang backup capacity",
            "status" => "conditional",
            "condition" => "Only if Peak Hanoi recycled shell buffer drops below 5 percent."
          }
        ]
      )

    assert html =~ "Mitigation checklist"
    assert html =~ "Re-quote landed cost with tariff delta"
    assert html =~ "required"
    assert html =~ "high"
    assert html =~ "blocking"
    assert html =~ "Merch ops"
    assert html =~ "Hold Lotus Da Nang backup capacity"
    assert html =~ "conditional"
    assert html =~ "Only if Peak Hanoi recycled shell buffer drops below 5 percent."
  end

  test "renders an empty state when no mitigation items are defined" do
    html = render_component(&MitigationChecklist.render/1, checklist_id: "empty_checklist")

    assert html =~ "No mitigation steps."
  end
end
