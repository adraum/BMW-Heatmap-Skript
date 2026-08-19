# Next Cycle Checklist

Use this checklist for each new analysis cycle.

## Update Steps

1. Replace the source-managed files at these paths:
- source/BMW_Watchouts.csv
- source/BMW_BG26-OI-R.csv
- data/runtime/web/Webconversion-organic-clean.csv
- data/runtime/web/Webconversion-paid-clean.csv
- data/runtime/web/HVNWR-clean.csv
- data/runtime/msf/MSF_IN.csv

2. If available, also replace the remaining source/reference files:
- source/Webconversion-organic.csv
- source/Webconversion-paid.csv
- source/HVNWR.csv
- source/MSF_IN.csv
- source/BMW_Media_C1.xlsx

3. Run the refresh workflow:
```powershell
.\tools\refresh_dashboard_data.ps1
```

Optional automatic mode during iterative updates:
```powershell
.\tools\watch_refresh_dashboard.ps1 -SkipMissingDataReport
```

4. Reload the dashboard:
- dashboard_watchout_recommendations_embedded.html

5. Results are loaded automatically after page load.

6. Validate a few known cases:
- Watchouts
- Root Cause
- Recommendations
- % of planned Sale

7. Generate fresh exports from the dashboard.

8. Do not reuse old exported CSV files from previous cycles.

## If Something Changed Structurally

If file names, column names, market codes, model codes, or business rules changed, also review:
- tools/templates/dashboard_watchout_recommendations.template.html
- tools/analyze_topsellers.ps1
- tools/build_msf_in_iwvv_ratio.ps1
- tools/build_missing_data_report.ps1

## Related Documentation

- docs/QUICK_START_GUIDE.md
- docs/DASHBOARD_DOCUMENTATION.md
- docs/DASHBOARD_MAINTENANCE_WORKFLOW.md
