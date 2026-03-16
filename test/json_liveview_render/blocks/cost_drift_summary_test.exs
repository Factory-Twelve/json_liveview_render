defmodule JsonLiveviewRender.Blocks.CostDriftSummaryTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonLiveviewRender.Blocks.CostDriftSummary

  test "renders estimated and negotiated totals alongside stage rows" do
    html =
      render_component(&CostDriftSummary.render/1,
        cost_summary_id: "cost_drift_dev_to_pp",
        stage_label: "Development to PP costing",
        status: "tightening",
        summary:
          "Negotiated totals are holding below estimate overall, but finishing and freight remain above plan.",
        currency: "USD",
        estimated_total: 19.4,
        negotiated_total: 18.95,
        approved_total: 18.75,
        delta_total: -0.45,
        stage_rows: [
          %{
            "stage_key" => "cut_make_trim",
            "stage_label" => "Cut make trim",
            "estimated_amount" => 11.2,
            "negotiated_amount" => 10.9,
            "approved_amount" => 10.9
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
        drivers: [
          %{
            "driver_key" => "freight_quote_refresh",
            "label" => "Freight quote refresh",
            "direction" => "increase",
            "amount" => 0.30,
            "summary" => "Latest ocean booking quote replaced the provisional rate."
          }
        ]
      )

    assert html =~ "Cost drift"
    assert html =~ "Development to PP costing"
    assert html =~ "19.4 USD"
    assert html =~ "18.95 USD"
    assert html =~ "-0.45 USD"
    assert html =~ "Cut make trim"
    assert html =~ "Freight"
    assert html =~ "Freight quote refresh"
    assert html =~ "increase"
  end

  test "drops malformed stage rows and drivers" do
    html =
      render_component(&CostDriftSummary.render/1,
        cost_summary_id: "cost_drift_dev_to_pp",
        stage_label: "Development to PP costing",
        status: "tightening",
        summary: "Summary",
        currency: "USD",
        estimated_total: 19.4,
        negotiated_total: 18.95,
        stage_rows: [
          %{
            "stage_key" => "cut_make_trim",
            "stage_label" => "Cut make trim",
            "estimated_amount" => 11.2
          },
          %{"stage_key" => "broken_row", "stage_label" => "Broken"}
        ],
        drivers: [
          %{"driver_key" => "freight_quote_refresh", "label" => "Freight quote refresh"},
          %{"driver_key" => "broken_driver"}
        ]
      )

    assert html =~ "Cut make trim"
    refute html =~ "broken_row"
    assert html =~ "Freight quote refresh"
    refute html =~ "broken_driver"
  end
end
