defmodule JsonLiveviewRender.Blocks.RevisionDeltaSummaryTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonLiveviewRender.Blocks.RevisionDeltaSummary

  test "renders mixed revision outcomes and change items" do
    html =
      render_component(&RevisionDeltaSummary.render/1,
        revision_id: "proposal_revision_r3",
        revision_label: "Proposal revision R3",
        status: "mixed",
        summary:
          "The revision resolves zipper sourcing and carton packing, but wash comments remain open.",
        baseline_label: "R2",
        candidate_label: "R3",
        changed_at: "2026-04-20T12:30:00Z",
        changed_by: "supplier_peak_textiles",
        change_counts: [
          %{"label" => "accepted", "count" => 4, "tone" => "positive"},
          %{"label" => "rejected", "count" => 1, "tone" => "critical"}
        ],
        change_items: [
          %{
            "change_id" => "revision_change_zipper_finish",
            "area" => "zipper finish",
            "disposition" => "accepted",
            "summary" => "Approved the matte nickel finish swap.",
            "impact" => "trim"
          },
          %{
            "change_id" => "revision_change_wash_recipe",
            "area" => "wash recipe",
            "disposition" => "rejected",
            "summary" => "Requested handfeel target is still not met.",
            "impact" => "quality"
          }
        ]
      )

    assert html =~ "Revision delta"
    assert html =~ "Proposal revision R3"
    assert html =~ "accepted"
    assert html =~ "rejected"
    assert html =~ "zipper finish"
    assert html =~ "wash recipe"
    assert html =~ "quality"
  end

  test "drops malformed change items" do
    html =
      render_component(&RevisionDeltaSummary.render/1,
        revision_id: "proposal_revision_r3",
        revision_label: "Proposal revision R3",
        status: "mixed",
        summary: "Summary",
        change_items: [
          %{
            "change_id" => "revision_change_zipper_finish",
            "area" => "zipper finish",
            "disposition" => "accepted",
            "summary" => "Approved the matte nickel finish swap."
          },
          %{"change_id" => "broken_change", "area" => "wash recipe"}
        ]
      )

    assert html =~ "zipper finish"
    refute html =~ "broken_change"
  end
end
