param(
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    # From source/, go up one level to repo root
    return (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function Read-TextFile {
    param(
        [string]$Path
    )

    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Escape-ScriptContent {
    param(
        [string]$Text
    )

    $json = $Text.Replace('</', '<\/')
    return $json
}

$repoRoot = Get-RepoRoot

# Set default output path if not provided
if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRoot 'dashboard_watchout_recommendations_embedded.html'
}

$templatePath = Join-Path $repoRoot 'tools\templates\dashboard_watchout_recommendations.template.html'
$template = Read-TextFile -Path $templatePath

# Always refresh source-driven runtime data before embedding.
& (Join-Path $repoRoot 'tools\refresh_dashboard_data.ps1') -SkipMissingDataReport

$assetPaths = @(
    'data/runtime/heatmaps/BMW_Watchouts.csv',
    'data/runtime/heatmaps/BMW_Chances.csv',
    'data/runtime/master/BMW_BG26-OI-R.csv',
    'data/runtime/web/Webconversion-organic-clean.csv',
    'data/runtime/web/Webconversion-paid-clean.csv',
    'data/runtime/web/HVNWR-clean.csv',
    'data/runtime/msf/MSF_IN.csv',
    'data/runtime/config/topsellers_per_market.json',
    'data/runtime/media/cs_organic_webconversion.json',
    'data/runtime/media/cs_paid_webconversion.json',
    'data/runtime/media/cost_per_nvwr_paid.json',
    'data/runtime/media/media_mix_paid_share.json',
    'data/runtime/media/media_cost_conversion_share.json',
    'data/runtime/media/media_total_cost.json',
    'data/runtime/media/msf_in_iwvv_ratio.json',
    'source/Webconversion-organic.csv',
    'source/Webconversion-paid.csv',
    'source/HVNWR.csv'
)

$textAssets = @{}
$jsonAssets = @{}

foreach ($relativePath in $assetPaths) {
    $fullPath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path $fullPath)) {
        throw "Missing required asset: $relativePath"
    }

    $extension = [System.IO.Path]::GetExtension($fullPath).ToLowerInvariant()
    switch ($extension) {
        '.json' {
            $jsonAssets[$relativePath] = Get-Content -Raw -Path $fullPath | ConvertFrom-Json
        }
        default {
            $textAssets[$relativePath] = Read-TextFile -Path $fullPath
        }
    }
}

$embeddedAssets = [ordered]@{
    textAssets = $textAssets
    jsonAssets = $jsonAssets
}

$embeddedJson = $embeddedAssets | ConvertTo-Json -Depth 100 -Compress
$embeddedJson = Escape-ScriptContent -Text $embeddedJson
$embeddedScript = "<script>window.__DASHBOARD_EMBEDDED_ASSETS__ = $embeddedJson;</script>"

if ($template -notmatch '<!-- EMBEDDED_DASHBOARD_ASSETS -->') {
    throw 'Embedding marker not found in dashboard template.'
}

$output = $template.Replace('<!-- EMBEDDED_DASHBOARD_ASSETS -->', "`r`n    $embeddedScript")

$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutputPath, $output, $encoding)
Write-Host "Wrote bundled dashboard to $OutputPath"
