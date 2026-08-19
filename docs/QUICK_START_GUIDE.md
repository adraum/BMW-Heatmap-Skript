# Quick Start Guide - Watchout Recommendations Dashboard

## Get Started in 5 Minutes

### 1. Open the Dashboard
Open dashboard_watchout_recommendations_embedded.html in your browser.

This version is self-contained and does not need the folder picker.

### 2. Wait for Data to Load
Check the status line at the bottom of the page.

Expected message:
```text
Data loaded. Ready for analysis.
```

### 3. Review the Default Filters
By default, all available markets and models are preselected.

The dashboard runs the first analysis automatically after data load.

You can:
- keep the full selection
- remove specific markets
- remove specific models
- use Reset to restore the default selection

### 4. Run the Analysis
Adjust filters and click Apply Filters only when you want to update the result set.

### 5. Review the Results
The dashboard updates the two analysis views:
- Summary
- Detailed Analysis

---

## What the Views Mean

### Summary
Use this view when you want a quick recommendation-centric output.

Each row shows:
- recommendation text
- model
- drivetrain
- market
- watchout labels

### Detailed Analysis
Use this view when you want the row-level explanation.

Each row shows:
- market
- model
- drivetrain
- retail-share reference
- identified watchouts
- root-cause findings
- recommendations with node references

---

## Common Use Cases

### Which models have the most issues?
1. Leave all filters selected.
2. Click Apply Filters.
3. Review the Detailed Analysis table.
4. Export if you want to sort or pivot in Excel.

### What is happening in one market?
1. Keep all models selected.
2. Select a single market, for example DE.
3. Click Apply Filters.
4. Review the Summary and Detailed Analysis output.

### Review BEV models only
1. Select the relevant BEV model ranges.
2. Keep the markets you want.
3. Click Apply Filters.

### Build a management export
1. Apply the relevant filters.
2. Review Summary for the high-level message.
3. Export Summary or Detailed Analysis.
4. Use Excel for final presentation formatting.

---

## Decision Tree Quick Reference

### Node A
- Trigger: IWVV or NVWR watchout
- Media recommendation depends on duration, Sales watchout, prediction, and Cost per NVWR

### Node B
- Trigger: NVWR watchout
- Checks organic and paid web conversion
- For CS, web conversion is evaluated as a regional aggregation across AT, BG, CZ, GR, HU, PL, RO, SI, SK
- Paid web conversion is treated as low below 0.7%

### Node C
- Trigger: CRM watchout
- Checks prediction, CRM watchout duration split, NSC Prospects, and High Value NVWR Share

### Node D
- Trigger: Sales-only or IWVV-and-Sales-only pattern
- Recommendation is blocked when prediction indicates a chance

---

## Export

### Summary Export
- File: watchout-recommendations-summary.csv
- Best for recommendation overviews

### Detailed Export
- File: watchout-recommendations-detailed.csv
- Best for validation, root-cause review, and Excel analysis

---

## Troubleshooting

### The dashboard does not load
1. Refresh the browser.
2. Confirm the source files still exist in the workspace.
3. Click `Select Repository Folder` in the dashboard footer and choose the project root.
4. Try another browser if local-file restrictions still interfere.

### No data appears after clicking Apply Filters
1. Make sure at least one market and one model are selected.
2. Wait for the data-loaded status message.
3. Use Reset and try again.

### Export does not download
1. Check browser download settings.
2. Disable restrictive popup/download blocking.
3. Try a different browser.

---

## FAQ

### When does the dashboard refresh its data?
It loads the local source files when the page opens. Reload the page to pick up new input files.

### Can thresholds be changed?
Yes, but that requires a code change in the dashboard logic.

### Why does a model show no watchouts?
Because none of the watchout conditions were triggered for that market-model-drivetrain combination.

### Can recommendations be exported as PDF?
Not directly. Export CSV first, then convert through Excel or another reporting tool.

Last Updated: 2026-07-21
