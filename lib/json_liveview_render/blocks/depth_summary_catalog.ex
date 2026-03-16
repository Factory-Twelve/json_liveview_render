defmodule JsonLiveviewRender.Blocks.DepthSummaryCatalog do
  @moduledoc """
  Internal experimental catalog for reusable depth review summary blocks.

  This surface is intentionally non-core and may change outside the stable v0.x
  contract.
  """

  use JsonLiveviewRender.Catalog

  component :risk_signal_summary do
    description("Risk signal summary block for reusable review and dashboard panels")
    prop(:signal_id, :string, required: true, doc: "Stable risk signal reference id")
    prop(:signal_key, :string, required: true)

    prop(:signal_type, :enum,
      required: true,
      values: ["tariff", "disruption", "capacity", "compliance", "quality"]
    )

    prop(:status, :enum, required: true, values: ["active", "monitoring", "resolved"])
    prop(:severity, :enum, required: true, values: ["low", "medium", "high"])
    prop(:summary, :string, required: true)
    prop(:observed_at, :string, required: true)

    prop(:effective_window, :map,
      default: %{},
      doc: "Window map with `start_at` and optional `end_at`"
    )

    prop(:source, :map,
      required: true,
      doc: "Source map with `source_kind`, `source_name`, and `reference`"
    )

    prop(:facts, {:list, :map},
      default: [],
      doc: "Fact maps with `fact_key`, `value`, and optional `unit`"
    )

    prop(:subject_impacts, {:list, :map},
      default: [],
      doc:
        "Impact maps with `subject_id`, `subject_kind`, `impact_type`, `severity`, and `summary`"
    )
  end

  component :feasibility_scorecard do
    description("Feasibility scorecard block for reusable review and dashboard panels")
    prop(:feasibility_id, :string, required: true, doc: "Stable feasibility reference id")
    prop(:status, :enum, required: true, values: ["feasible", "feasible_with_risks", "blocked"])
    prop(:confidence, :float, required: true)
    prop(:summary, :string, required: true)
    prop(:requested_units, :integer)
    prop(:target_ship_date, :string)
    prop(:requested_currency, :string)
    prop(:recommended_plan_id, :string)

    prop(:candidate_plans, {:list, :map},
      default: [],
      doc:
        "Plan maps with `plan_id`, `supplier_id`, `facility_id`, `available_capacity_units`, `estimated_unit_cost`, and optional `earliest_start_at` plus `earliest_completion_at`"
    )

    prop(:constraints, {:list, :map},
      default: [],
      doc:
        "Constraint maps with `constraint_key`, `category`, `severity`, `blocking`, `summary`, and optional `related_subject_ids`"
    )

    prop(:warnings, {:list, :map},
      default: [],
      doc: "Warning maps with `code`, `severity`, and `message`"
    )
  end

  component :mitigation_checklist do
    description("Mitigation checklist block for reusable review and dashboard panels")
    prop(:checklist_id, :string, required: true, doc: "Stable mitigation checklist reference id")
    prop(:summary, :string)

    prop(:items, {:list, :map},
      default: [],
      doc:
        "Checklist item maps with `item_id`, `label`, `status`, and optional `blocking`, `summary`, `condition`, `owner`, `due_at`, and `severity`"
    )
  end

  component :logistics_scenario_summary do
    description("Logistics scenario summary block for reusable review and dashboard panels")
    prop(:scenario_id, :string, required: true, doc: "Stable logistics scenario reference id")
    prop(:scenario_key, :string, required: true)
    prop(:scenario_status, :enum, required: true, values: ["on_track", "at_risk", "blocked"])
    prop(:summary, :string, required: true)
    prop(:shipment_units, :integer)
    prop(:ready_at, :string)
    prop(:estimated_arrival_at, :string)
    prop(:total_transit_days, :float, required: true)
    prop(:origin_country, :string)
    prop(:destination_country, :string)
    prop(:incoterm, :string)
    prop(:signal_ids, {:list, :string}, default: [])

    prop(:route_legs, {:list, :map},
      default: [],
      doc: "Leg maps with `sequence`, `mode`, `origin`, `destination`, and `transit_days`"
    )

    prop(:cost_breakdown, {:list, :map},
      default: [],
      doc: "Cost maps with `cost_type`, `amount`, and `currency`"
    )

    prop(:risk_flags, {:list, :map},
      default: [],
      doc: "Risk flag maps with `code`, `severity`, and `message`"
    )

    prop(:route_alternatives, {:list, :map},
      default: [],
      doc:
        "Alternative maps with `scenario_id`, optional `label`, optional `scenario_status`, and optional `tradeoff`"
    )
  end
end
