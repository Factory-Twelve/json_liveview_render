defmodule JsonLiveviewRender.Blocks.LifecycleSummaryCatalog do
  @moduledoc """
  Internal experimental catalog for reusable lifecycle summary blocks.

  This surface is intentionally non-core and may change outside the stable v0.x
  contract.
  """

  use JsonLiveviewRender.Catalog

  component :sample_round_summary do
    description("Sample round summary block for reusable timeline, detail, and review panels")
    prop(:sample_round_id, :string, required: true, doc: "Stable sample round reference id")
    prop(:round_label, :string, required: true)
    prop(:status, :string, required: true)
    prop(:summary, :string, required: true)
    prop(:round_type, :string)
    prop(:owner, :string)
    prop(:requested_at, :string)
    prop(:reviewed_at, :string)
    prop(:decision_due_at, :string)

    prop(:disposition_counts, {:list, :map},
      default: [],
      doc: "Count maps with `label`, `count`, and optional `tone`"
    )

    prop(:findings, {:list, :map},
      default: [],
      doc: "Finding maps with `finding_id`, `area`, `status`, `summary`, and optional `impact`"
    )

    prop(:next_steps, {:list, :map},
      default: [],
      doc:
        "Step maps with `step_id`, `label`, and optional `status`, `summary`, `owner`, and `due_at`"
    )
  end

  component :revision_delta_summary do
    description("Revision delta summary block for reusable timeline, detail, and review panels")
    prop(:revision_id, :string, required: true, doc: "Stable revision reference id")
    prop(:revision_label, :string, required: true)
    prop(:status, :string, required: true)
    prop(:summary, :string, required: true)
    prop(:baseline_label, :string)
    prop(:candidate_label, :string)
    prop(:changed_at, :string)
    prop(:changed_by, :string)

    prop(:change_counts, {:list, :map},
      default: [],
      doc: "Count maps with `label`, `count`, and optional `tone`"
    )

    prop(:change_items, {:list, :map},
      default: [],
      doc:
        "Change item maps with `change_id`, `area`, `disposition`, `summary`, and optional `impact`"
    )
  end

  component :cost_drift_summary do
    description("Cost drift summary block for reusable timeline, detail, and review panels")
    prop(:cost_summary_id, :string, required: true, doc: "Stable cost summary reference id")
    prop(:stage_label, :string, required: true)
    prop(:status, :string, required: true)
    prop(:summary, :string, required: true)
    prop(:currency, :string)
    prop(:estimated_total, :float, required: true)
    prop(:negotiated_total, :float, required: true)
    prop(:approved_total, :float)
    prop(:delta_total, :float)

    prop(:stage_rows, {:list, :map},
      default: [],
      doc:
        "Stage maps with `stage_key`, `stage_label`, optional `estimated_amount`, `negotiated_amount`, `approved_amount`, `delta_amount`, and optional `summary`"
    )

    prop(:drivers, {:list, :map},
      default: [],
      doc:
        "Driver maps with `driver_key`, `label`, and optional `direction`, `amount`, and `summary`"
    )
  end

  component :operation_breakdown_highlights do
    description(
      "Operation breakdown highlight block for reusable timeline, detail, and review panels"
    )

    prop(:operation_breakdown_id, :string,
      required: true,
      doc: "Stable operation breakdown reference id"
    )

    prop(:breakdown_label, :string, required: true)
    prop(:status, :string, required: true)
    prop(:summary, :string, required: true)
    prop(:supplier_label, :string)
    prop(:facility_label, :string)
    prop(:total_operations, :integer)
    prop(:total_smv, :float)
    prop(:manual_share_pct, :float)

    prop(:highlights, {:list, :map},
      default: [],
      doc:
        "Highlight maps with `operation_key`, `label`, and optional `workstation`, `change_type`, `smv`, `cost_share_pct`, and `summary`"
    )

    prop(:flags, {:list, :map},
      default: [],
      doc: "Flag maps with `code`, `severity`, and `message`"
    )
  end
end
