defmodule JsonLiveviewRender.Blocks.DepthSummaryRegistry do
  @moduledoc """
  Internal experimental registry for reusable depth review summary blocks.

  This surface is intentionally non-core and may change outside the stable v0.x
  contract.
  """

  use JsonLiveviewRender.Registry, catalog: JsonLiveviewRender.Blocks.DepthSummaryCatalog

  alias JsonLiveviewRender.Blocks.{
    FeasibilityScorecard,
    Layout,
    LogisticsScenarioSummary,
    MitigationChecklist,
    RiskSignalSummary
  }

  render(:row, &Layout.row/1)
  render(:column, &Layout.column/1)
  render(:section, &Layout.section/1)
  render(:grid, &Layout.grid/1)
  render(:risk_signal_summary, &RiskSignalSummary.render/1)
  render(:feasibility_scorecard, &FeasibilityScorecard.render/1)
  render(:mitigation_checklist, &MitigationChecklist.render/1)
  render(:logistics_scenario_summary, &LogisticsScenarioSummary.render/1)
end
