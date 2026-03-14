defmodule JsonLiveviewRender.Blocks.ArtifactPreviewRegistry do
  @moduledoc """
  Internal experimental registry for reusable artifact preview side-panel
  blocks.

  This surface is intentionally non-core and may change outside the stable v0.x
  contract.
  """

  use JsonLiveviewRender.Registry, catalog: JsonLiveviewRender.Blocks.ArtifactPreviewCatalog

  alias JsonLiveviewRender.Blocks.{
    ArtifactPreviewApprovalSummary,
    ArtifactPreviewEvidenceSummary,
    ArtifactPreviewHeader,
    ArtifactPreviewLineageSummary,
    Layout
  }

  render(:row, &Layout.row/1)
  render(:column, &Layout.column/1)
  render(:section, &Layout.section/1)
  render(:grid, &Layout.grid/1)
  render(:artifact_preview_header, &ArtifactPreviewHeader.render/1)
  render(:artifact_preview_lineage_summary, &ArtifactPreviewLineageSummary.render/1)
  render(:artifact_preview_approval_summary, &ArtifactPreviewApprovalSummary.render/1)
  render(:artifact_preview_evidence_summary, &ArtifactPreviewEvidenceSummary.render/1)
end
