param(
    [switch]$SkipMissingDataReport
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Test-RequiredFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Required file not found: $Path"
    }
}

function Sync-SourceToRuntime {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$RuntimePath
    )

    if (-not (Test-Path $SourcePath)) {
        throw "Required source file not found: $SourcePath"
    }

    $runtimeDir = Split-Path -Parent $RuntimePath
    if (-not (Test-Path $runtimeDir)) {
        New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
    }

    Copy-Item -Path $SourcePath -Destination $RuntimePath -Force
}

function Build-CleanRuntimeCsv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$RuntimePath
    )

    & (Join-Path $repoRoot 'tools\clean_csv.ps1') -InputFile $SourcePath -OutputFile $RuntimePath
}

Write-Host '=== Refresh Dashboard Data ==='
Write-Host "Repository root: $repoRoot"
Write-Host ''

$requiredInputs = @(
    'source/BMW_BG26-OI-R.csv',
    'source/BMW_Media_C1.xlsx',
    'source/MSF_IN.csv',
    'source/BMW_Watchouts.csv',
    'source/BMW_Chances.csv',
    'source/Webconversion-organic.csv',
    'source/Webconversion-paid.csv',
    'source/HVNWR.csv'
)

Write-Host 'Checking required inputs...'
$requiredInputs | ForEach-Object { Test-RequiredFile $_ }
Write-Host 'All required inputs found.'
Write-Host ''

Write-Host 'Syncing source files to runtime...'
Sync-SourceToRuntime -SourcePath 'source/BMW_BG26-OI-R.csv' -RuntimePath 'data/runtime/master/BMW_BG26-OI-R.csv'
Sync-SourceToRuntime -SourcePath 'source/BMW_Watchouts.csv' -RuntimePath 'data/runtime/heatmaps/BMW_Watchouts.csv'
Sync-SourceToRuntime -SourcePath 'source/BMW_Chances.csv' -RuntimePath 'data/runtime/heatmaps/BMW_Chances.csv'
Sync-SourceToRuntime -SourcePath 'source/MSF_IN.csv' -RuntimePath 'data/runtime/msf/MSF_IN.csv'
Write-Host 'Source to runtime sync complete.'
Write-Host ''

Write-Host '1. Rebuilding runtime clean web CSVs from source...'
Build-CleanRuntimeCsv -SourcePath 'source/Webconversion-organic.csv' -RuntimePath 'data/runtime/web/Webconversion-organic-clean.csv'
Build-CleanRuntimeCsv -SourcePath 'source/Webconversion-paid.csv' -RuntimePath 'data/runtime/web/Webconversion-paid-clean.csv'
Build-CleanRuntimeCsv -SourcePath 'source/HVNWR.csv' -RuntimePath 'data/runtime/web/HVNWR-clean.csv'
Test-RequiredFile 'data/runtime/web/Webconversion-organic-clean.csv'
Test-RequiredFile 'data/runtime/web/Webconversion-paid-clean.csv'
Test-RequiredFile 'data/runtime/web/HVNWR-clean.csv'
Write-Host ''

Write-Host '2. Rebuilding media runtime JSONs from source/BMW_Media_C1.xlsx...'
& (Join-Path $repoRoot 'tools\build_media_runtime_jsons.ps1')
Test-RequiredFile 'data/runtime/media/cs_organic_webconversion.json'
Test-RequiredFile 'data/runtime/media/cs_paid_webconversion.json'
Test-RequiredFile 'data/runtime/media/cost_per_nvwr_paid.json'
Test-RequiredFile 'data/runtime/media/media_mix_paid_share.json'
Test-RequiredFile 'data/runtime/media/media_cost_conversion_share.json'
Test-RequiredFile 'data/runtime/media/media_total_cost.json'
Write-Host ''

Write-Host '3. Rebuilding topsellers configuration...'
& (Join-Path $repoRoot 'tools\analyze_topsellers.ps1')
Test-RequiredFile 'data/runtime/config/topsellers_per_market.json'
Write-Host ''

Write-Host '4. Rebuilding MSF IWVV ratio lookup...'
& (Join-Path $repoRoot 'tools\build_msf_in_iwvv_ratio.ps1')
Test-RequiredFile 'data/runtime/media/msf_in_iwvv_ratio.json'
Write-Host ''

if (-not $SkipMissingDataReport) {
    Write-Host '5. Rebuilding missing-data coverage reports...'
    & (Join-Path $repoRoot 'tools\build_missing_data_report.ps1')
    Test-RequiredFile 'data/generated/reports/missing_data_report_topsellers.csv'
    Test-RequiredFile 'data/generated/reports/missing_data_only_topsellers.csv'
    Write-Host ''
} else {
    Write-Host '5. Skipped missing-data coverage reports.'
    Write-Host ''
}

Write-Host 'Refresh complete.'
Write-Host 'Next steps:'
Write-Host '- If you need a fresh embedded HTML, run tools/build_self_contained_dashboard.ps1 (it already includes refresh)'
Write-Host '- Reload dashboard_watchout_recommendations_embedded.html'
Write-Host '- Verify a few known market-model cases'
Write-Host '- Export fresh dashboard CSVs if needed'
