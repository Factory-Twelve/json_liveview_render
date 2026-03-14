defmodule JsonLiveviewRender.Blocks.ArtifactPreviewCatalog do
  @moduledoc """
  Internal experimental catalog for reusable artifact preview side-panel blocks.

  This surface is intentionally non-core and may change outside the stable v0.x
  contract.
  """

  use JsonLiveviewRender.Catalog

  component :artifact_preview_header do
    description("Artifact header block for reusable detail and preview panels")
    prop(:artifact_id, :string, required: true, doc: "Stable artifact reference id")
    prop(:artifact_type, :string, required: true)
    prop(:title, :string, required: true)
    prop(:status, :string, required: true)
    prop(:version, :string, required: true)
    prop(:summary, :string)
    prop(:owner, :string)
    prop(:updated_at, :string)
  end

  component :artifact_preview_lineage_summary do
    description("Lineage summary block for reusable artifact preview panels")
    prop(:artifact_id, :string, required: true)

    prop(:lineage_state, :string,
      required: true,
      doc: "Current lineage state such as current, superseded, or derived"
    )

    prop(:summary, :string)

    prop(:relationships, {:list, :map},
      default: [],
      doc:
        "Relationship groups with `label` plus `refs`; each ref should include `artifact_id`, optional `title`, and optional `status`"
    )
  end

  component :artifact_preview_approval_summary do
    description("Approval summary block for reusable artifact preview panels")
    prop(:artifact_id, :string, required: true)
    prop(:overall_state, :string, required: true)
    prop(:requested_at, :string)
    prop(:decided_at, :string)
    prop(:summary, :string)

    prop(:reviewers, {:list, :map},
      default: [],
      doc: "Reviewer maps with `name`, `status`, and optional `role`, `decided_at`, and `note`"
    )
  end

  component :artifact_preview_evidence_summary do
    description("Evidence summary block for reusable artifact preview panels")
    prop(:artifact_id, :string, required: true)
    prop(:total_count, :integer, required: true)
    prop(:latest_captured_at, :string)
    prop(:summary, :string)

    prop(:source_breakdown, {:list, :map},
      default: [],
      doc: "Source breakdown maps with `label` and `count`"
    )

    prop(:evidence_refs, {:list, :map},
      default: [],
      doc:
        "Evidence reference maps with `ref_id`, `title`, and optional `source_type`, `captured_at`, and `uri`"
    )
  end
end
