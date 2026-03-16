defmodule JsonLiveviewRender.Blocks.FeasibilityScorecardTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonLiveviewRender.Blocks.FeasibilityScorecard

  test "renders recommended plans, constraints, and warnings" do
    html =
      render_component(&FeasibilityScorecard.render/1,
        feasibility_id: "production_feasibility_alpine_hoodie_may",
        status: "feasible_with_risks",
        confidence: 0.78,
        summary:
          "Peak Hanoi can cover the requested window with material watchouts; Lotus Da Nang remains fallback only.",
        requested_units: 18_000,
        target_ship_date: "2026-05-20",
        requested_currency: "USD",
        recommended_plan_id: "feasibility_plan_peak_hanoi",
        candidate_plans: [
          %{
            "plan_id" => "feasibility_plan_peak_hanoi",
            "supplier_id" => "supplier_peak_textiles",
            "facility_id" => "facility_peak_hanoi",
            "earliest_start_at" => "2026-04-02T00:00:00Z",
            "earliest_completion_at" => "2026-05-08T00:00:00Z",
            "available_capacity_units" => 22_000,
            "estimated_unit_cost" => 18.4
          }
        ],
        constraints: [
          %{
            "constraint_key" => "lotus_capacity_gap",
            "category" => "capacity",
            "severity" => "high",
            "blocking" => true,
            "summary" =>
              "Lotus Da Nang cannot cover the full order volume without a second facility split.",
            "related_subject_ids" => ["supplier_lotus_apparel", "facility_lotus_danang"]
          }
        ],
        warnings: [
          %{
            "code" => "recycled_shell_buffer_tight",
            "severity" => "medium",
            "message" =>
              "Recycled shell inventory leaves minimal upside buffer if the order expands."
          }
        ]
      )

    assert html =~ "Feasibility"
    assert html =~ "Confidence 0.78"
    assert html =~ "feasibility_plan_peak_hanoi"
    assert html =~ "supplier_peak_textiles"
    assert html =~ "18.4 USD"
    assert html =~ "lotus_capacity_gap"
    assert html =~ "blocking"
    assert html =~ "supplier_lotus_apparel, facility_lotus_danang"
    assert html =~ "recycled_shell_buffer_tight"
  end
end
