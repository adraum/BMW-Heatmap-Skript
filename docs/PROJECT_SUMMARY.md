# Watchout Recommendations Dashboard - Project Summary

## Deliverables

The project delivers an interactive HTML dashboard for automated BMW funnel-watchout analysis, together with supporting documentation and export capability.

### Main Application
- dashboard_watchout_recommendations_embedded.html
- tools/templates/dashboard_watchout_recommendations.template.html
- responsive HTML dashboard
- local CSV and JSON data integration
- rule-based decision tree for nodes A, B, C, and D
- summary and detailed analysis views
- CSV export for both views

### Documentation
- docs/DASHBOARD_DOCUMENTATION.md
- docs/QUICK_START_GUIDE.md
- docs/DASHBOARD_MAINTENANCE_WORKFLOW.md

---

## Implemented Features

### Filters
- multi-select markets
- multi-select models
- default full selection
- apply and reset actions
- dropdown panels with checkbox options

### Analysis Logic
- Node A: upper-funnel watchout logic
- Node B: web-conversion checks for NVWR watchouts
- Node C: CRM follow-up logic using prediction, duration, NSC Prospects, and HVNWR share
- Node D: Sales-only and IWVV-plus-Sales-only logic with prediction gate

### Outputs
- Summary table
- Detailed Analysis table
- status line
- CSV exports

---

## Current Business Rules Snapshot

### Watchout Detection
- IWVV watchout: WEB indicates IWVV or a negative watchout marker
- NVWR watchout: WEB indicates NVWR or a negative watchout marker
- CRM watchout: CRM is negative
- Sales watchout: SALES < 0
- Duration >= 3 months: any relevant field contains -3

### KPI Thresholds
- Organic web conversion low: < 0.9%
- Paid web conversion low: < 0.7%
- High Value NVWR Share OK: >= 40%
- Cost per NVWR efficient: <= 200 EUR for BEV or <= 100 EUR for NON-BEV, and Paid Share < 60%
- Fallback for missing organic web conversion: use overall web conversion (`NVWR / IWVV`) from MSF
- Root-cause wording for fallback cases: `Overall Webconversion`

### CS Regional Handling
- CS web conversion (organic and paid) is evaluated as a regional aggregation across AT, BG, CZ, GR, HU, PL, RO, SI, SK.
- CS Cost per NVWR and Paid Share are also evaluated as regional aggregates across the same CS country set.

---

## Validation Status

Recent updates include:
- revised Node A branching and recommendation flow
- revised Node C branching order
- Sales watchout logic changed to SALES < 0 only
- revised Node D prediction gate
- English-language dashboard UI
- multiselect dropdown filters with checkbox options

---

## Known Constraints

1. Existing exported CSV files in the workspace may reflect older logic.
2. Duration handling depends on explicit -3 markers in the heatmap source.
3. Missing lookup data can lead to fallback behavior, especially for cost efficiency.

---

## Recommended Next Steps

1. Re-run the dashboard and generate fresh exports.
2. Reconcile older CSV outputs with the latest rules before sharing them.
3. Extend documentation further if additional business rules change.

---

Project Status: Active and updated  
Last Updated: 2026-07-21
