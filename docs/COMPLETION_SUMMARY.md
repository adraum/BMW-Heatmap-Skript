# Dashboard Completion Summary

## Status

The BMW Watchout Recommendations Dashboard is implemented, restructured, documented, and ready to use with the current local dataset.

Main application:
- dashboard_watchout_recommendations_embedded.html

Template source:
- tools/templates/dashboard_watchout_recommendations.template.html

---

## What Is Included

### Application
- single-file HTML dashboard
- local CSV and JSON runtime inputs
- decision-tree logic for nodes A, B, C, and D
- summary and detailed analysis views
- CSV export

### Data Structure
- runtime files under `data/runtime/`
- source/reference files under `source/`
- generated reports and exports under `data/generated/`
- archived non-runtime files under `archive/`

Current `source/` files present:
- source/BMW_Watchouts.csv
- source/BMW_BG26-OI-R.csv
- source/Webconversion-organic.csv
- source/Webconversion-paid.csv
- source/HVNWR.csv
- source/MSF_IN.csv
- source/BMW_Media_C1.xlsx

### Tooling
- tools/analyze_topsellers.ps1
- tools/build_msf_in_iwvv_ratio.ps1
- tools/build_missing_data_report.ps1
- tools/refresh_dashboard_data.ps1

### Documentation
- docs/QUICK_START_GUIDE.md
- docs/DASHBOARD_DOCUMENTATION.md
- docs/DASHBOARD_MAINTENANCE_WORKFLOW.md
- docs/PROJECT_SUMMARY.md

---

## Key Functional Updates Applied

### Decision Logic
- Node A updated to the latest requested A.1, A.2, A.3, A.4, A.10 flow
- Node C reordered to the requested C.1, C.2, C.3, C.4 sequence
- Node D updated to block the sales recommendation when prediction indicates a chance
- Sales watchout logic changed to `SALES < 0` only

### UI
- dashboard translated to English
- filter controls changed from plain multi-select boxes to dropdown panels with checkbox options
- status and export labels aligned to English UI

### Repository Structure
- app moved to `app/`
- runtime data moved to `data/runtime/`
- source data moved to `source/`
- generated outputs moved to `data/generated/`
- scripts moved to `tools/`
- documentation moved to `docs/`

---

## Runtime Dependencies

The dashboard currently requires these runtime inputs:
- data/runtime/heatmaps/BMW_Watchouts.csv
- data/runtime/master/BMW_BG26-OI-R.csv
- data/runtime/web/Webconversion-organic-clean.csv
- data/runtime/web/Webconversion-paid-clean.csv
- data/runtime/web/HVNWR-clean.csv
- data/runtime/msf/MSF_IN.csv
- data/runtime/config/topsellers_per_market.json
- data/runtime/media/cs_organic_webconversion.json
- data/runtime/media/cs_paid_webconversion.json
- data/runtime/media/cost_per_nvwr_paid.json
- data/runtime/media/media_mix_paid_share.json
- data/runtime/media/media_total_cost.json
- data/runtime/media/msf_in_iwvv_ratio.json

---

## Recommended Operating Workflow

1. Update source or runtime data files (watchouts/master are maintained in `source/`).
2. Run `tools/refresh_dashboard_data.ps1`.
3. Run `tools/build_self_contained_dashboard.ps1`.
4. Reload `dashboard_watchout_recommendations_embedded.html`.
4. Verify a few known market-model cases.
5. Export fresh CSV outputs if needed.

---

## Notes

- Existing exported CSV files should be treated as stale after any logic or data update.
- The dashboard output is rebuilt via `tools/build_self_contained_dashboard.ps1`.
- The refresh workflow is documented in `docs/DASHBOARD_MAINTENANCE_WORKFLOW.md`.

Last Updated: 2026-07-20
