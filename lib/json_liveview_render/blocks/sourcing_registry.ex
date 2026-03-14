defmodule JsonLiveviewRender.Blocks.SourcingRegistry do
  @moduledoc """
  Internal experimental registry for wedge sourcing side-panel blocks.

  This surface is intentionally non-core and may change outside the stable v0.x
  contract.
  """

  use JsonLiveviewRender.Registry, catalog: JsonLiveviewRender.Blocks.SourcingCatalog

  alias JsonLiveviewRender.Blocks.{
    ApprovalAction,
    ApprovalWidget,
    ArtifactSummary,
    EvidenceCard,
    Layout,
    PolicyFlag
  }

  render(:row, &Layout.row/1)
  render(:column, &Layout.column/1)
  render(:section, &Layout.section/1)
  render(:grid, &Layout.grid/1)
  render(:sourcing_evidence_card, &EvidenceCard.render/1)
  render(:sourcing_artifact_summary, &ArtifactSummary.render/1)
  render(:sourcing_policy_flag, &PolicyFlag.render/1)
  render(:sourcing_approval_action, &ApprovalAction.render/1)
  render(:sourcing_approval_widget, &ApprovalWidget.render/1)
end
