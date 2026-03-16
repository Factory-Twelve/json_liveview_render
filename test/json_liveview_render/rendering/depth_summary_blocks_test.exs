defmodule JsonLiveviewRender.Rendering.DepthSummaryBlocksTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Blocks.DepthSummaryCatalog
  alias JsonLiveviewRender.Blocks.DepthSummaryRegistry
  alias JsonLiveviewRender.Spec

  @valid_spec %{
    "root" => "panel",
    "elements" => %{
      "panel" => %{
        "type" => "column",
        "props" => %{"gap" => "md"},
        "children" => [
          "signal_section",
          "feasibility_section",
          "mitigation_section",
          "logistics_section"
        ]
      },
      "signal_section" => %{
        "type" => "section",
        "props" => %{"title" => "Signal"},
        "children" => ["risk_signal"]
      },
      "risk_signal" => %{
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
            %{"fact_key" => "affected_hs_code", "value" => "6201.40"},
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
      },
      "feasibility_section" => %{
        "type" => "section",
        "props" => %{"title" => "Feasibility"},
        "children" => ["feasibility_scorecard"]
      },
      "feasibility_scorecard" => %{
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
              "earliest_start_at" => "2026-04-02T00:00:00Z",
              "earliest_completion_at" => "2026-05-08T00:00:00Z",
              "available_capacity_units" => 22_000,
              "estimated_unit_cost" => 18.4
            },
            %{
              "plan_id" => "feasibility_plan_lotus_danang",
              "supplier_id" => "supplier_lotus_apparel",
              "facility_id" => "facility_lotus_danang",
              "earliest_completion_at" => "2026-05-19T00:00:00Z",
              "available_capacity_units" => 9_000,
              "estimated_unit_cost" => 19.7
            }
          ],
          "constraints" => [
            %{
              "constraint_key" => "recycled_shell_cert_rollover",
              "category" => "material",
              "severity" => "medium",
              "blocking" => false,
              "summary" =>
                "Certified recycled shell inventory covers only a narrow overrun buffer.",
              "related_subject_ids" => ["supplier_peak_textiles", "facility_peak_hanoi"]
            },
            %{
              "constraint_key" => "lotus_capacity_gap",
              "category" => "capacity",
              "severity" => "high",
              "blocking" => true,
              "summary" =>
                "Lotus Da Nang cannot cover the full order volume without a second facility split.",
              "related_subject_ids" => ["supplier_lotus_apparel", "facility_lotus_danang"]
            }
          ],
          "warnings" => [
            %{
              "code" => "recycled_shell_buffer_tight",
              "severity" => "medium",
              "message" =>
                "Recycled shell inventory leaves minimal upside buffer if the order expands."
            }
          ]
        },
        "children" => []
      },
      "mitigation_section" => %{
        "type" => "section",
        "props" => %{"title" => "Mitigations"},
        "children" => ["mitigation_checklist"]
      },
      "mitigation_checklist" => %{
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
              "summary" => "Decision cannot move forward until landed cost is restated.",
              "owner" => "Merch ops",
              "due_at" => "2026-03-18"
            },
            %{
              "item_id" => "hold_backup_capacity",
              "label" => "Hold Lotus Da Nang backup capacity",
              "status" => "conditional",
              "summary" => "Preserve recovery capacity if the preferred plan slips.",
              "condition" => "Only if Peak Hanoi recycled shell buffer drops below 5 percent."
            }
          ]
        },
        "children" => []
      },
      "logistics_section" => %{
        "type" => "section",
        "props" => %{"title" => "Logistics"},
        "children" => ["logistics_summary"]
      },
      "logistics_summary" => %{
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
            },
            %{
              "sequence" => 2,
              "mode" => "ocean",
              "origin" => "Hai Phong Port",
              "destination" => "Port of Oakland",
              "transit_days" => 19
            },
            %{
              "sequence" => 3,
              "mode" => "truck",
              "origin" => "Port of Oakland",
              "destination" => "Reno Consolidation DC",
              "transit_days" => 2
            }
          ],
          "cost_breakdown" => [
            %{"cost_type" => "freight", "amount" => 42_800, "currency" => "USD"},
            %{"cost_type" => "duty", "amount" => 33_750, "currency" => "USD"},
            %{"cost_type" => "handling", "amount" => 6_900, "currency" => "USD"}
          ],
          "risk_flags" => [
            %{
              "code" => "tariff_watch_open",
              "severity" => "high",
              "message" =>
                "Tariff watch remains unresolved and could materially increase landed cost."
            },
            %{
              "code" => "oakland_congestion_buffer",
              "severity" => "medium",
              "message" =>
                "Oakland berth congestion leaves less than three days of delivery slack."
            }
          ],
          "route_alternatives" => [
            %{
              "scenario_id" => "logistics_scenario_alpine_air_partial",
              "label" => "Partial air bridge",
              "scenario_status" => "on_track",
              "tradeoff" => "Improves delivery confidence but increases landed cost."
            },
            %{
              "scenario_id" => "logistics_scenario_alpine_gulf_route",
              "label" => "Gulf port reroute",
              "scenario_status" => "blocked",
              "tradeoff" => "Avoids Oakland congestion but misses the target arrival window."
            }
          ]
        },
        "children" => []
      }
    }
  }

  test "validates depth summary specs" do
    assert {:ok, _spec} = Spec.validate(@valid_spec, DepthSummaryCatalog)
  end

  test "rejects invalid feasibility confidence types" do
    spec =
      put_in(
        @valid_spec,
        ["elements", "feasibility_scorecard", "props", "confidence"],
        "high"
      )

    assert {:error, reasons} = Spec.validate(spec, DepthSummaryCatalog)
    assert Enum.any?(reasons, fn {tag, _message} -> tag == :invalid_prop_type end)
  end

  test "renders risk, feasibility, mitigation, and logistics summary blocks" do
    html =
      JsonLiveviewRender.Test.render_spec(@valid_spec, DepthSummaryCatalog,
        registry: DepthSummaryRegistry,
        current_user: %{},
        bindings: %{}
      )

    assert html =~ "Signal"
    assert html =~ "vietnam_apparel_tariff_watch"
    assert html =~ "Apex Trade Monitor"
    assert html =~ "Feasibility"
    assert html =~ "supplier_peak_textiles"
    assert html =~ "recycled_shell_buffer_tight"
    assert html =~ "Mitigations"
    assert html =~ "Re-quote landed cost with tariff delta"
    assert html =~ "conditional"
    assert html =~ "Logistics"
    assert html =~ "Peak Hanoi Factory to Hai Phong Port"
    assert html =~ "oakland_congestion_buffer"
    assert html =~ "Partial air bridge"
  end
end
