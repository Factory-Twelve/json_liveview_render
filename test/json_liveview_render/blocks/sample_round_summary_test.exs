defmodule JsonLiveviewRender.Blocks.SampleRoundSummaryTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonLiveviewRender.Blocks.SampleRoundSummary

  test "renders sample round dispositions, findings, and next steps" do
    html =
      render_component(&SampleRoundSummary.render/1,
        sample_round_id: "sample_round_pp2_alpine_hoodie",
        round_label: "PP sample round 2",
        status: "needs_revision",
        summary:
          "Body fit is acceptable, but cuff tolerance and zipper pull revisions remain open before sign-off.",
        round_type: "pp",
        owner: "Merch ops",
        requested_at: "2026-04-08",
        reviewed_at: "2026-04-14",
        decision_due_at: "2026-04-18",
        disposition_counts: [
          %{"label" => "accepted", "count" => 6, "tone" => "positive"},
          %{"label" => "revise", "count" => 2, "tone" => "warning"}
        ],
        findings: [
          %{
            "finding_id" => "sample_finding_cuff_opening",
            "area" => "cuff opening",
            "status" => "revise",
            "summary" => "Opening still runs 0.5 cm above tolerance on size M.",
            "impact" => "fit"
          }
        ],
        next_steps: [
          %{
            "step_id" => "next_step_recut_cuff",
            "label" => "Re-cut cuff pattern and resubmit shell",
            "status" => "required",
            "summary" => "Send the corrected cuff for same-day fit review.",
            "owner" => "Peak Hanoi",
            "due_at" => "2026-04-17"
          }
        ]
      )

    assert html =~ "Sample round"
    assert html =~ "PP sample round 2"
    assert html =~ "accepted"
    assert html =~ "revise"
    assert html =~ "cuff opening"
    assert html =~ "fit"
    assert html =~ "Re-cut cuff pattern and resubmit shell"
    assert html =~ "Peak Hanoi"
  end

  test "drops malformed findings and next steps" do
    html =
      render_component(&SampleRoundSummary.render/1,
        sample_round_id: "sample_round_pp2_alpine_hoodie",
        round_label: "PP sample round 2",
        status: "needs_revision",
        summary: "Summary",
        findings: [
          %{
            "finding_id" => "sample_finding_cuff_opening",
            "area" => "cuff opening",
            "status" => "revise",
            "summary" => "Opening still runs 0.5 cm above tolerance on size M."
          },
          %{"finding_id" => "broken_finding", "area" => "zipper"}
        ],
        next_steps: [
          %{"step_id" => "next_step_recut_cuff", "label" => "Re-cut cuff pattern"},
          %{"step_id" => "broken_step"}
        ]
      )

    assert html =~ "cuff opening"
    refute html =~ "broken_finding"
    assert html =~ "Re-cut cuff pattern"
    refute html =~ "broken_step"
  end
end
