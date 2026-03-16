# Depth Summary Blocks RC1

Status: Internal experimental companion surface (non-core contract).

`JsonLiveviewRender.Blocks.DepthSummaryCatalog` and
`JsonLiveviewRender.Blocks.DepthSummaryRegistry` provide a reusable reference
bundle for risk-signal, feasibility, mitigation, and logistics secondary
summary panels consumed by Workbench and related review surfaces.

Included block types:

- `risk_signal_summary`
- `feasibility_scorecard`
- `mitigation_checklist`
- `logistics_scenario_summary`

Scope notes:

- This bundle is for declarative summary panels only.
- Workbench should shape upstream contract objects into block props before
  rendering; business scoring and recommendation logic stay outside
  `json_liveview_render`.
- Scenario comparison grids and route tables remain out of scope and should stay
  in app-specific surfaces such as AG Grid.

Nested payload shape notes:

- `risk_signal_summary.effective_window` expects a map with `start_at` and
  optional `end_at`.
- `risk_signal_summary.source` expects `source_kind`, `source_name`, and
  `reference`.
- `risk_signal_summary.facts` expects maps with `fact_key`, `value`, and
  optional `unit`.
- `risk_signal_summary.subject_impacts` expects maps with `subject_id`,
  `subject_kind`, `impact_type`, `severity`, and `summary`.
- `feasibility_scorecard.candidate_plans` expects maps with `plan_id`,
  `supplier_id`, `facility_id`, `available_capacity_units`,
  `estimated_unit_cost`, and optional `earliest_start_at` plus
  `earliest_completion_at`.
- `feasibility_scorecard.constraints` expects maps with `constraint_key`,
  `category`, `severity`, `blocking`, `summary`, and optional
  `related_subject_ids`.
- `feasibility_scorecard.warnings` expects maps with `code`, `severity`, and
  `message`.
- `mitigation_checklist.items` expects maps with `item_id`, `label`, `status`,
  and optional `blocking`, `summary`, `condition`, `owner`, `due_at`, and
  `severity`.
- `logistics_scenario_summary.route_legs` expects maps with `sequence`, `mode`,
  `origin`, `destination`, and `transit_days`.
- `logistics_scenario_summary.cost_breakdown` expects maps with `cost_type`,
  `amount`, and `currency`.
- `logistics_scenario_summary.risk_flags` expects maps with `code`, `severity`,
  and `message`.
- `logistics_scenario_summary.route_alternatives` expects maps with
  `scenario_id`, optional `label`, optional `scenario_status`, and optional
  `tradeoff`.

Example render setup:

```elixir
JsonLiveviewRender.Test.render_spec(spec, JsonLiveviewRender.Blocks.DepthSummaryCatalog,
  registry: JsonLiveviewRender.Blocks.DepthSummaryRegistry,
  current_user: %{}
)
```

Example payload excerpts:

```elixir
%{
  "type" => "risk_signal_summary",
  "props" => %{
    "signal_id" => "risk_signal_vietnam_tariff_watch",
    "signal_key" => "vietnam_apparel_tariff_watch",
    "signal_type" => "tariff",
    "status" => "active",
    "severity" => "high",
    "summary" =>
      "Proposed US tariff surcharge on Vietnam-sourced outerwear could raise landed cost before May bookings lock.",
    "observed_at" => "2026-03-15T13:45:00Z",
    "effective_window" => %{"start_at" => "2026-04-01T00:00:00Z"},
    "source" => %{
      "source_kind" => "trade_feed",
      "source_name" => "Apex Trade Monitor",
      "reference" => "trade-alert-2026-03-15-vn-outerwear"
    },
    "facts" => [
      %{"fact_key" => "tariff_delta_pct", "value" => 12.5, "unit" => "percent"}
    ],
    "subject_impacts" => [
      %{
        "subject_id" => "supplier_peak_textiles",
        "subject_kind" => "supplier",
        "impact_type" => "cost",
        "severity" => "high",
        "summary" => "Supplier pricing requires re-quoting if the surcharge lands."
      }
    ]
  },
  "children" => []
}

%{
  "type" => "feasibility_scorecard",
  "props" => %{
    "feasibility_id" => "production_feasibility_alpine_hoodie_may",
    "status" => "feasible_with_risks",
    "confidence" => 0.78,
    "summary" =>
      "Peak Hanoi can cover the requested window with material watchouts; Lotus Da Nang remains fallback only.",
    "requested_units" => 18_000,
    "target_ship_date" => "2026-05-20",
    "requested_currency" => "USD",
    "recommended_plan_id" => "feasibility_plan_peak_hanoi",
    "candidate_plans" => [
      %{
        "plan_id" => "feasibility_plan_peak_hanoi",
        "supplier_id" => "supplier_peak_textiles",
        "facility_id" => "facility_peak_hanoi",
        "available_capacity_units" => 22_000,
        "estimated_unit_cost" => 18.4,
        "earliest_completion_at" => "2026-05-08T00:00:00Z"
      }
    ],
    "constraints" => [
      %{
        "constraint_key" => "lotus_capacity_gap",
        "category" => "capacity",
        "severity" => "high",
        "blocking" => true,
        "summary" => "Lotus Da Nang cannot cover the full order volume without a split.",
        "related_subject_ids" => ["supplier_lotus_apparel", "facility_lotus_danang"]
      }
    ],
    "warnings" => [
      %{
        "code" => "recycled_shell_buffer_tight",
        "severity" => "medium",
        "message" => "Recycled shell inventory leaves minimal upside buffer."
      }
    ]
  },
  "children" => []
}

%{
  "type" => "mitigation_checklist",
  "props" => %{
    "checklist_id" => "mitigation_feasibility_alpine",
    "summary" => "Separate hard blocks from conditional follow-through work.",
    "items" => [
      %{
        "item_id" => "requote_tariff_exposure",
        "label" => "Re-quote landed cost with tariff delta",
        "status" => "required",
        "blocking" => true,
        "severity" => "high",
        "summary" => "Decision cannot move forward until landed cost is restated."
      },
      %{
        "item_id" => "hold_backup_capacity",
        "label" => "Hold Lotus Da Nang backup capacity",
        "status" => "conditional",
        "condition" => "Only if Peak Hanoi recycled shell buffer drops below 5 percent."
      }
    ]
  },
  "children" => []
}

%{
  "type" => "logistics_scenario_summary",
  "props" => %{
    "scenario_id" => "logistics_scenario_alpine_ocean_split",
    "scenario_key" => "alpine_ocean_split_vietnam_us",
    "scenario_status" => "at_risk",
    "summary" =>
      "Keep the Hanoi FOB booking and route through Oakland, but tariff exposure and port congestion keep the scenario at risk.",
    "shipment_units" => 18_000,
    "ready_at" => "2026-05-08T00:00:00Z",
    "estimated_arrival_at" => "2026-05-31T00:00:00Z",
    "total_transit_days" => 22.5,
    "origin_country" => "VN",
    "destination_country" => "US",
    "incoterm" => "FOB",
    "signal_ids" => ["risk_signal_vietnam_tariff_watch"],
    "route_legs" => [
      %{
        "sequence" => 1,
        "mode" => "truck",
        "origin" => "Peak Hanoi Factory",
        "destination" => "Hai Phong Port",
        "transit_days" => 1.5
      }
    ],
    "cost_breakdown" => [
      %{"cost_type" => "freight", "amount" => 42_800, "currency" => "USD"}
    ],
    "risk_flags" => [
      %{
        "code" => "tariff_watch_open",
        "severity" => "high",
        "message" => "Tariff watch remains unresolved before departure."
      }
    ],
    "route_alternatives" => [
      %{
        "scenario_id" => "logistics_scenario_alpine_air_partial",
        "label" => "Partial air bridge",
        "scenario_status" => "on_track",
        "tradeoff" => "Improves delivery confidence but increases landed cost."
      }
    ]
  },
  "children" => []
}
```
