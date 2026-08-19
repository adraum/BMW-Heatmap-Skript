# PerfLoop Dashboard

## Overview

This repository contains the BMW Watchout Recommendations Dashboard and the files needed to run and maintain it.

The active dashboard is a self-contained single HTML file with embedded runtime data.

Main app:
- dashboard_watchout_recommendations_embedded.html

Template source:
- tools/templates/dashboard_watchout_recommendations.template.html

## Repository Structure

```text
PerfLoop/
  app/
    dashboard_watchout_recommendations_embedded.html

  data/
    runtime/
      config/
      heatmaps/
      master/
      media/
      msf/
      web/
    source/
      web/
      msf/
      media/
    generated/
      exports/
      reports/

  tools/
    analyze_topsellers.ps1
    build_missing_data_report.ps1
    build_msf_in_iwvv_ratio.ps1
    build_self_contained_dashboard.ps1
    refresh_dashboard_data.ps1
    templates/
      dashboard_watchout_recommendations.template.html

  docs/
    DASHBOARD_DOCUMENTATION.md
    DASHBOARD_MAINTENANCE_WORKFLOW.md
    QUICK_START_GUIDE.md
    PROJECT_SUMMARY.md
    COMPLETION_SUMMARY.md

  archive/
```

## Runtime Files Required by the Dashboard

The dashboard reads these files directly:
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

## Source Files Currently Present

The repository currently contains these source/reference files under `source/`:
- source/BMW_Watchouts.csv
- source/BMW_BG26-OI-R.csv
- source/Webconversion-organic.csv
- source/Webconversion-paid.csv
- source/HVNWR.csv
- source/MSF_IN.csv
- source/BMW_Media_C1.xlsx

These are the only source files currently present. Additional source Excel or export files are not required for the current dashboard runtime.

## Open the Dashboard

Open:
- dashboard_watchout_recommendations_embedded.html

The bundled file is self-contained and does not need the folder picker.
The initial analysis runs automatically after data load, so results are shown immediately.
To regenerate it from the current data files, run:

```powershell
.\tools\build_self_contained_dashboard.ps1
```

When changing dashboard logic or UI, edit the template file and then rebuild the embedded output.

## Refresh Data Workflow

When new source data arrives:

1. Replace the currently used files in `source/` and runtime-only direct inputs in `data/runtime/`.
  - Maintain `BMW_Watchouts.csv` and `BMW_BG26-OI-R.csv` in `source/`.
  - Maintain `MSF_IN.csv`, `Webconversion-organic.csv`, `Webconversion-paid.csv`, and `HVNWR.csv` in `source/`.
  - Maintain `BMW_Media_C1.xlsx` in `source/`.
  - `tools/refresh_dashboard_data.ps1` automatically syncs source files into `data/runtime/` where needed.
  - `tools/refresh_dashboard_data.ps1` automatically rebuilds runtime clean web CSVs in `data/runtime/web/` from source CSVs.
  - `tools/refresh_dashboard_data.ps1` automatically regenerates media JSONs in `data/runtime/media/` from `source/BMW_Media_C1.xlsx`.
2. Run:

```powershell
.\tools\refresh_dashboard_data.ps1
```

3. Reload the dashboard in the browser.
4. Generate fresh exports from the dashboard if needed.

## Tooling

### Refresh everything needed for a normal data update

```powershell
.\tools\refresh_dashboard_data.ps1
```

### Rebuild embedded dashboard end-to-end from current source files

This command now runs refresh automatically (without missing-data report) and then embeds all updated assets:

```powershell
.\tools\build_self_contained_dashboard.ps1
```

### Run automatic refresh on file changes

This watches `source/`, `data/runtime/web/`, `data/runtime/msf/`, `data/runtime/media/`, and the dashboard template.
When files change, it runs refresh automatically (and rebuilds the embedded dashboard by default).

```powershell
.\tools\watch_refresh_dashboard.ps1
```

Useful options:

```powershell
# Faster cycles without missing-data report
.\tools\watch_refresh_dashboard.ps1 -SkipMissingDataReport

# Only refresh data, skip embedded dashboard rebuild
.\tools\watch_refresh_dashboard.ps1 -RefreshOnly
```

### Rebuild only topsellers config

```powershell
.\tools\analyze_topsellers.ps1
```

### Rebuild the MSF ratio lookup

```powershell
.\tools\build_msf_in_iwvv_ratio.ps1
```

### Rebuild the missing-data coverage reports

```powershell
.\tools\build_missing_data_report.ps1
```

## Documentation

Start here depending on what you need:
- docs/QUICK_START_GUIDE.md
- docs/DASHBOARD_DOCUMENTATION.md
- docs/DASHBOARD_MAINTENANCE_WORKFLOW.md

## Notes

- Old exported CSV files can become stale after any logic or data update.
- The dashboard has a build step for the self-contained output: `./tools/build_self_contained_dashboard.ps1`.
- The runtime JSON files under `data/runtime/media/` are required by the app.
- `cost_per_nvwr_paid.json`, `media_mix_paid_share.json`, `media_total_cost.json`, and `cs_paid_webconversion.json` are generated automatically from `source/BMW_Media_C1.xlsx`.
