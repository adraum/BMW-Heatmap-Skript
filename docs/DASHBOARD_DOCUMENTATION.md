# BMW Watchout Recommendations Dashboard - Documentation

## Overview

The Watchout Recommendations Dashboard is an interactive HTML-based analysis tool for BMW funnel watchouts across markets and models. It evaluates watchout combinations with a decision tree and produces actionable recommendations for media, website, CRM, and sales topics.

Runtime File: dashboard_watchout_recommendations_embedded.html  
Template File: tools/templates/dashboard_watchout_recommendations.template.html  
Location: /PerfLoop/app/  
Language: English  
Technology: HTML5, CSS3, JavaScript (ES6+), Papa Parse

---

## Core Capabilities

### Filters and Selection
- Market multiselect with checkbox options inside a dropdown panel
- Model multiselect with checkbox options inside a dropdown panel
- All markets and models are preselected on load
- Apply Filters runs the analysis
- Reset restores the default selection

### Dashboard Outputs
- Summary view: recommendation-centric output grouped by recommendation text
- Detailed Analysis view: watchouts, root-cause findings, and node references per market-model-drivetrain row
- CSV export for both views

### Data Sources
- data/runtime/heatmaps/BMW_Watchouts.csv
- data/runtime/web/Webconversion-organic-clean.csv
- data/runtime/web/Webconversion-paid-clean.csv
- data/runtime/web/HVNWR-clean.csv
- data/runtime/master/BMW_BG26-OI-R.csv
- data/runtime/media/cost_per_nvwr_paid.json
- data/runtime/media/media_mix_paid_share.json
- data/runtime/media/media_total_cost.json
- data/runtime/media/msf_in_iwvv_ratio.json
- data/runtime/media/cs_organic_webconversion.json
- data/runtime/media/cs_paid_webconversion.json

---

## Decision Tree Logic

### Node A: Upper Funnel Watchouts
- Trigger: watchout in IWVV or NVWR
- A.1 checks whether the case is IWVV-only, without NVWR, CRM, or Sales
- A.1b checks whether the case is NVWR-only, without IWVV, CRM, or Sales; if yes, it skips A.4 and proceeds directly with B
- A.2 checks whether the watchout exists for at least 3 months
- A.3 checks whether either Sales watchout exists and prediction is not a chance, or prediction indicates a risk
- A.4 checks Cost per NVWR efficiency
- Node A can recommend either increasing media activities or adjusting media mix

### Node B: Upper Funnel Conversion Analysis
- Trigger: NVWR watchout
- Checks organic web conversion and paid web conversion
- If organic web conversion is missing, it falls back to overall web conversion using `NVWR / IWVV` from MSF (latest available values)
- For market CS, web conversion is evaluated as a regional aggregation across AT, BG, CZ, GR, HU, PL, RO, SI, SK
- Can recommend website-journey or media-campaign review
- In root-cause text, fallback-based results are labeled as `Overall Webconversion` (not `Organic Webconversion`)

### Node C: CRM Analysis
- Trigger: CRM watchout
- Checks prediction, CRM-specific 3-month duration split (routing either to D or C.3), NSC Prospects, and High Value NVWR Share
- Can recommend lead generation or prospect nurturing

### Node D: Sales Analysis
- Trigger: Sales-only or IWVV-and-Sales-only pattern
- Recommendation is blocked when prediction indicates a chance
- Otherwise it recommends lead-quality review and potential COR measures

---

## Watchout Detection Rules

| Watchout Type | Rule | Source |
|---|---|---|
| IWVV | WEB contains IWVV or a negative watchout indicator | Heatmap |
| NVWR | WEB contains NVWR or a negative watchout indicator | Heatmap |
| CRM | CRM contains a negative watchout indicator or numeric value below 0 | Heatmap |
| Sales | SALES below 0 | Heatmap |
| Duration at least 3 months | Any relevant heatmap field contains -3 | Heatmap |

---

## KPI Thresholds

| KPI | OK | Not OK | Source |
|---|---|---|---|
| Organic web conversion | >= 0.9% | < 0.9% | Web |
| Paid web conversion | >= 0.7% | < 0.7% | Web |
| High Value NVWR Share | >= 40% | < 40% | HVNWR |
| NSC Prospects | >= benchmark | < benchmark | MSF |
| Cost per NVWR BEV | <= 200 EUR and Paid Share < 60% | > 200 EUR or Paid Share >= 60% | Media + MSF |
| Cost per NVWR NON-BEV | <= 100 EUR and Paid Share < 60% | > 100 EUR or Paid Share >= 60% | Media + MSF |

CS specifics:
- CS web conversion (organic and paid) is aggregated across AT, BG, CZ, GR, HU, PL, RO, SI, SK.
- CS Cost per NVWR and Paid Share are also evaluated as regional aggregates across the same CS country set.

Fallback specifics:
- If organic web conversion is unavailable, the dashboard uses overall web conversion (`NVWR / IWVV`) from MSF.

---

## Views

### Summary
Columns:
- Recommendation
- Model
- Drivetrain
- Market
- Watchouts

### Detailed Analysis
Columns:
- Market
- Model
- Drivetrain
- % of Planned Retail
- Identified Watchouts
- Identified Root Cause
- Recommendations

---

## Exports

### Summary Export
Filename: watchout-recommendations-summary.csv

Columns:
- Recommendation
- Model
- Drivetrain
- Market
- Decision Tree Node

### Detailed Export
Filename: watchout-recommendations-detailed.csv

Columns:
- Market
- Model
- Drivetrain
- % of Planned Retail
- Identified Watchouts
- Root Cause
- Recommendations

---

## Technical Notes

### Architecture
- Frontend-only HTML application
- CSV and JSON inputs loaded locally through Fetch
- Papa Parse used for CSV parsing
- Lookup maps built in memory for fast evaluation

### Maintenance Workflow
- Exact create/update workflow: see docs/DASHBOARD_MAINTENANCE_WORKFLOW.md

### Country Mapping
- BELUX is normalized to BELU for selected lookup files
- CS is treated as a regional market for web conversion and Cost per NVWR checks
- CH is mapped to DE where applicable

---

## Known Limitations

1. Duration logic depends on explicit -3 markers in the heatmap source.
2. If Cost per NVWR data is missing, Paid Share is still evaluated; efficiency cannot be confirmed without Cost per NVWR.
3. Retail share may be N/A when the master data has no matching value.
4. Export files in the workspace may reflect older runs and not the latest code unless re-generated.

---

Version: 1.1  
Last Updated: 2026-07-23
