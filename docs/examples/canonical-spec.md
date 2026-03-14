# Canonical Spec Example

This example shows the canonical internal shape and the kind of stable ids that
future patch formats should target.

## Worked Example

```json
{
  "root": "revenue_dashboard_page",
  "elements": {
    "revenue_dashboard_page": {
      "type": "column",
      "props": {
        "gap": "md"
      },
      "children": ["revenue_summary_section", "revenue_trends_row"]
    },
    "revenue_summary_section": {
      "type": "section",
      "props": {
        "title": "Revenue Snapshot",
        "collapsible": false
      },
      "children": ["metric_revenue_total", "metric_margin_total"]
    },
    "metric_revenue_total": {
      "type": "metric",
      "props": {
        "label": "Revenue",
        "value": "$48k",
        "trend": "up"
      },
      "children": []
    },
    "metric_margin_total": {
      "type": "metric",
      "props": {
        "label": "Margin",
        "value": "38%",
        "trend": "flat"
      },
      "children": []
    },
    "revenue_trends_row": {
      "type": "row",
      "props": {
        "gap": "sm"
      },
      "children": ["metric_new_accounts", "metric_churn_rate"]
    },
    "metric_new_accounts": {
      "type": "metric",
      "props": {
        "label": "New Accounts",
        "value": "124",
        "trend": "up"
      },
      "children": []
    },
    "metric_churn_rate": {
      "type": "metric",
      "props": {
        "label": "Churn",
        "value": "1.8%",
        "trend": "down"
      },
      "children": []
    }
  }
}
```

## Why These Ids Are Stable

- `metric_revenue_total` stays the same id if only its `value` or `trend`
  changes.
- Adding a new sibling under `revenue_trends_row` creates one new id and one new
  child reference; it does not rename `metric_new_accounts`.
- Reordering children changes the `children` array order, not the ids
  themselves.
- Patches can target `/elements/metric_churn_rate/props/value` without knowing
  the metric's position in a list.

## What Not To Do

Avoid ids whose meaning depends only on transient position, such as
`metric_1`, `metric_2`, `metric_3`, when those ids would be renumbered every
time the layout changes. Stable ids are what make partial accumulation, patch
application, and reviewable diffs deterministic.
