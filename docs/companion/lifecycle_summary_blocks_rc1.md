# Lifecycle Summary Blocks RC1

Status: Internal experimental companion surface (non-core contract).

`JsonLiveviewRender.Blocks.LifecycleSummaryCatalog` and
`JsonLiveviewRender.Blocks.LifecycleSummaryRegistry` provide a reusable
reference bundle for lifecycle-oriented secondary panels such as sample rounds,
revision deltas, stage-cost drift, and operation breakdown highlights.

Included block types:

- `sample_round_summary`
- `revision_delta_summary`
- `cost_drift_summary`
- `operation_breakdown_highlights`

Scope notes:

- This bundle is for declarative summary panels only.
- Workbench should shape lifecycle contract objects into block props before
  rendering; scoring, acceptance logic, and workflow actions stay outside
  `json_liveview_render`.
- Spreadsheet-like comparison tables remain out of scope and should stay in
  app-specific surfaces such as AG Grid.

Nested payload shape notes:

- `sample_round_summary.disposition_counts` expects maps with `label`, `count`,
  and optional `tone`.
- `sample_round_summary.findings` expects maps with `finding_id`, `area`,
  `status`, `summary`, and optional `impact`.
- `sample_round_summary.next_steps` expects maps with `step_id`, `label`, and
  optional `status`, `summary`, `owner`, and `due_at`.
- `revision_delta_summary.change_counts` expects maps with `label`, `count`,
  and optional `tone`.
- `revision_delta_summary.change_items` expects maps with `change_id`, `area`,
  `disposition`, `summary`, and optional `impact`.
- `cost_drift_summary.stage_rows` expects maps with `stage_key`, `stage_label`,
  optional `estimated_amount`, `negotiated_amount`, `approved_amount`,
  `delta_amount`, and optional `summary`.
- `cost_drift_summary.drivers` expects maps with `driver_key`, `label`, and
  optional `direction`, `amount`, and `summary`.
- `operation_breakdown_highlights.highlights` expects maps with
  `operation_key`, `label`, and optional `workstation`, `change_type`, `smv`,
  `cost_share_pct`, and `summary`.
- `operation_breakdown_highlights.flags` expects maps with `code`, `severity`,
  and `message`.

Example render setup:

```elixir
JsonLiveviewRender.Test.render_spec(spec, JsonLiveviewRender.Blocks.LifecycleSummaryCatalog,
  registry: JsonLiveviewRender.Blocks.LifecycleSummaryRegistry,
  current_user: %{}
)
```

Example payload excerpts:

```elixir
%{
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
        "owner" => "Peak Hanoi",
        "due_at" => "2026-04-17"
      }
    ]
  },
  "children" => []
}

%{
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
}

%{
  "type" => "cost_drift_summary",
  "props" => %{
    "cost_summary_id" => "cost_drift_dev_to_pp",
    "stage_label" => "Development to PP costing",
    "status" => "tightening",
    "summary" =>
      "Negotiated totals are holding below estimate overall, but finishing and freight remain above plan.",
    "currency" => "USD",
    "estimated_total" => 19.40,
    "negotiated_total" => 18.95,
    "approved_total" => 18.75,
    "delta_total" => -0.45,
    "stage_rows" => [
      %{
        "stage_key" => "cut_make_trim",
        "stage_label" => "Cut make trim",
        "estimated_amount" => 11.20,
        "negotiated_amount" => 10.90,
        "approved_amount" => 10.90
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
}

%{
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
```
