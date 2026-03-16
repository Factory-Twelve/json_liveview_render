defmodule JsonLiveviewRender.Blocks.LifecycleSummaryRegistry do
  @moduledoc """
  Internal experimental registry for reusable lifecycle summary blocks.

  This surface is intentionally non-core and may change outside the stable v0.x
  contract.
  """

  use JsonLiveviewRender.Registry, catalog: JsonLiveviewRender.Blocks.LifecycleSummaryCatalog

  alias JsonLiveviewRender.Blocks.{
    CostDriftSummary,
    Layout,
    OperationBreakdownHighlights,
    RevisionDeltaSummary,
    SampleRoundSummary
  }

  render(:row, &Layout.row/1)
  render(:column, &Layout.column/1)
  render(:section, &Layout.section/1)
  render(:grid, &Layout.grid/1)
  render(:sample_round_summary, &SampleRoundSummary.render/1)
  render(:revision_delta_summary, &RevisionDeltaSummary.render/1)
  render(:cost_drift_summary, &CostDriftSummary.render/1)
  render(:operation_breakdown_highlights, &OperationBreakdownHighlights.render/1)
end
