defmodule JsonLiveviewRender.Rendering.LifecycleSummaryBlocksTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Blocks.LifecycleSummaryCatalog
  alias JsonLiveviewRender.Blocks.LifecycleSummaryRegistry
  alias JsonLiveviewRender.Spec

  @valid_spec %{
    "root" => "panel",
    "elements" => %{
      "panel" => %{
        "type" => "column",
        "props" => %{"gap" => "md"},
        "children" => [
          "sample_section",
          "revision_section",
          "cost_section",
          "operation_section"
        ]
      },
      "sample_section" => %{
        "type" => "section",
        "props" => %{"title" => "Sample"},
        "children" => ["sample_round"]
      },
      "sample_round" => %{
        "type" => "sample_round_summary",
        "props" => %{
          "sample_round_id" => "sample_round_pp2_alpine_hoodie",
          "round_label" => "PP sample round 2",
          "status" => "needs_revision",
          "summary" =>
            "Body fit is acceptable, but cuff tolerance and zipper pull revisions remain open before sign-off.",
          "round_type" => "pp",
          "owner" => "Merch ops",
          "requested_at" => "2026-04-08",
          "reviewed_at" => "2026-04-14",
          "decision_due_at" => "2026-04-18",
          "disposition_counts" => [
            %{"label" => "accepted", "count" => 6, "tone" => "positive"},
            %{"label" => "revise", "count" => 2, "tone" => "warning"}
          ],
          "findings" => [
            %{
              "finding_id" => "sample_finding_cuff_opening",
              "area" => "cuff opening",
              "status" => "revise",
              "summary" => "Opening still runs 0.5 cm above tolerance on size M.",
              "impact" => "fit"
            }
          ],
          "next_steps" => [
            %{
              "step_id" => "next_step_recut_cuff",
              "label" => "Re-cut cuff pattern and resubmit shell",
              "status" => "required",
              "summary" => "Send the corrected cuff for same-day fit review.",
              "owner" => "Peak Hanoi",
              "due_at" => "2026-04-17"
            }
          ]
        },
        "children" => []
      },
      "revision_section" => %{
        "type" => "section",
        "props" => %{"title" => "Revision"},
        "children" => ["revision_delta"]
      },
      "revision_delta" => %{
        "type" => "revision_delta_summary",
        "props" => %{
          "revision_id" => "proposal_revision_r3",
          "revision_label" => "Proposal revision R3",
          "status" => "mixed",
          "summary" =>
            "The revision resolves zipper sourcing and carton packing, but wash comments remain open.",
          "baseline_label" => "R2",
          "candidate_label" => "R3",
          "changed_at" => "2026-04-20T12:30:00Z",
          "changed_by" => "supplier_peak_textiles",
          "change_counts" => [
            %{"label" => "accepted", "count" => 4, "tone" => "positive"},
            %{"label" => "rejected", "count" => 1, "tone" => "critical"}
          ],
          "change_items" => [
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
        },
        "children" => []
      },
      "cost_section" => %{
        "type" => "section",
        "props" => %{"title" => "Cost"},
        "children" => ["cost_drift"]
      },
      "cost_drift" => %{
        "type" => "cost_drift_summary",
        "props" => %{
          "cost_summary_id" => "cost_drift_dev_to_pp",
          "stage_label" => "Development to PP costing",
          "status" => "tightening",
          "summary" =>
            "Negotiated totals are holding below estimate overall, but finishing and freight remain above plan.",
          "currency" => "USD",
          "estimated_total" => 19.4,
          "negotiated_total" => 18.95,
          "approved_total" => 18.75,
          "delta_total" => -0.45,
          "stage_rows" => [
            %{
              "stage_key" => "cut_make_trim",
              "stage_label" => "Cut make trim",
              "estimated_amount" => 11.2,
              "negotiated_amount" => 10.9,
              "approved_amount" => 10.9
            },
            %{
              "stage_key" => "freight",
              "stage_label" => "Freight",
              "estimated_amount" => 1.15,
              "negotiated_amount" => 1.45,
              "delta_amount" => 0.30,
              "summary" => "Routing update increased freight above the original estimate."
            }
          ],
          "drivers" => [
            %{
              "driver_key" => "freight_quote_refresh",
              "label" => "Freight quote refresh",
              "direction" => "increase",
              "amount" => 0.30,
              "summary" => "Latest ocean booking quote replaced the provisional rate."
            }
          ]
        },
        "children" => []
      },
      "operation_section" => %{
        "type" => "section",
        "props" => %{"title" => "Operations"},
        "children" => ["operation_breakdown"]
      },
      "operation_breakdown" => %{
        "type" => "operation_breakdown_highlights",
        "props" => %{
          "operation_breakdown_id" => "operation_breakdown_peak_hanoi_pp",
          "breakdown_label" => "Peak Hanoi PP route",
          "status" => "review",
          "summary" =>
            "The sewing path is stable, but pressing and pack-out remain the main SMV and cost-share watchpoints.",
          "supplier_label" => "Peak Textiles",
          "facility_label" => "Peak Hanoi",
          "total_operations" => 18,
          "total_smv" => 24.8,
          "manual_share_pct" => 81.0,
          "highlights" => [
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
          "flags" => [
            %{
              "code" => "packout_manual_dependency",
              "severity" => "medium",
              "message" => "Pack-out still depends on a manual fold-and-bag station."
            }
          ]
        },
        "children" => []
      }
    }
  }

  test "validates lifecycle summary specs" do
    assert {:ok, _spec} = Spec.validate(@valid_spec, LifecycleSummaryCatalog)
  end

  test "rejects invalid cost total types" do
    spec =
      put_in(
        @valid_spec,
        ["elements", "cost_drift", "props", "estimated_total"],
        "19.4"
      )

    assert {:error, reasons} = Spec.validate(spec, LifecycleSummaryCatalog)
    assert Enum.any?(reasons, fn {tag, _message} -> tag == :invalid_prop_type end)
  end

  test "renders sample, revision, cost, and operation summary blocks" do
    html =
      JsonLiveviewRender.Test.render_spec(@valid_spec, LifecycleSummaryCatalog,
        registry: LifecycleSummaryRegistry,
        current_user: %{},
        bindings: %{}
      )

    assert html =~ "Sample"
    assert html =~ "PP sample round 2"
    assert html =~ "Re-cut cuff pattern and resubmit shell"
    assert html =~ "Revision"
    assert html =~ "zipper finish"
    assert html =~ "wash recipe"
    assert html =~ "Cost"
    assert html =~ "18.95 USD"
    assert html =~ "Freight quote refresh"
    assert html =~ "Operations"
    assert html =~ "Press and finish"
    assert html =~ "packout_manual_dependency"
  end
end
