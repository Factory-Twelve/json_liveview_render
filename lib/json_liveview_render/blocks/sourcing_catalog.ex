defmodule JsonLiveviewRender.Blocks.SourcingCatalog do
  @moduledoc """
  Internal experimental catalog for wedge sourcing side-panel blocks.

  This surface is intentionally non-core and may change outside the stable v0.x
  contract.
  """

  use JsonLiveviewRender.Catalog

  component :sourcing_evidence_card do
    description("Evidence reference card for sourcing wedge side panels")
    prop(:ref_id, :string, required: true, doc: "Stable evidence reference id")

    prop(:source_type, :enum,
      required: true,
      values: ["spec_sheet", "email", "lab_report", "image"]
    )

    prop(:title, :string, required: true)
    prop(:uri, :string, required: true)
    prop(:captured_at, :string, required: true)
    prop(:excerpt, :string)
  end

  component :sourcing_artifact_summary do
    description("Artifact summary card for sourcing wedge side panels")
    prop(:artifact_id, :string, required: true)

    prop(:artifact_type, :enum,
      required: true,
      values: ["spec_digest", "cost_summary", "qa_packet"]
    )

    prop(:title, :string, required: true)
    prop(:status, :enum, required: true, values: ["draft", "ready", "approved"])
    prop(:version, :string, required: true)
    prop(:generated_from_evidence_ids, {:list, :string}, default: [])
  end

  component :sourcing_policy_flag do
    description("Policy or risk badge for sourcing wedge side panels")
    prop(:code, :string, required: true)
    prop(:severity, :enum, required: true, values: ["low", "medium", "high"])
    prop(:message, :string, required: true)
  end

  component :sourcing_approval_action do
    description("Static approval action control for sourcing wedge side panels")
    prop(:action_id, :string, required: true)
    prop(:label, :string, required: true)
    prop(:tone, :enum, values: ["primary", "secondary", "danger"], default: "secondary")
    prop(:disabled, :boolean, default: false)
    prop(:disabled_reason, :string)
  end

  component :sourcing_approval_widget do
    description("Approval summary widget for sourcing wedge side panels")
    prop(:approval_id, :string, required: true)
    prop(:subject_id, :string, required: true)
    prop(:decision, :enum, required: true, values: ["approved", "rejected", "needs_review"])
    prop(:actor, :string, required: true)
    prop(:decided_at, :string, required: true)
    prop(:rationale, :string)
    prop(:read_only, :boolean, default: false)
    prop(:disabled_reason, :string)
  end
end
