$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$msfPath = Join-Path $repoRoot 'data\runtime\msf\MSF_IN.csv'
$ratioOut = Join-Path $repoRoot 'data\runtime\media\msf_in_iwvv_ratio.json'

$rows = Import-Csv $msfPath
if (-not $rows -or $rows.Count -eq 0) {
    throw 'MSF_IN CSV is empty.'
}

$countryMap = @{
    'AT'='AT'; 'BE'='BELU'; 'BELUX'='BELU'; 'BG'='BG'; 'CZ'='CZ'; 'CS'='CZ';
    'DE'='DE'; 'ES'='ES'; 'FR'='FR'; 'GB'='GB'; 'GR'='GR'; 'HU'='HU';
    'IT'='IT'; 'JP'='JP'; 'KR'='KR'; 'NL'='NL'; 'PL'='PL'; 'RO'='RO';
    'SI'='SI'; 'SK'='SK'; 'CH'='DE'; 'US'='US'
}

function Resolve-MarketCode([string]$countryCode) {
    $k = ($countryCode + '').Trim().ToUpper()
    if ($countryMap.ContainsKey($k)) { return $countryMap[$k] }
    return $k
}

$iwvvKpi = 'Interacting Vehicle Web Visits - All'
$iwvvPaidKpi = 'Interacting Vehicle Web Visits - Paid'
$latest = @{}

foreach ($r in $rows) {
    $kpi = ($r.KPI + '').Trim()
    if ($kpi -ne $iwvvKpi -and $kpi -ne $iwvvPaidKpi) { continue }

    $market = Resolve-MarketCode $r.'Country Code'
    $model = (($r.'Model Range' + '').Trim().ToUpper())
    $dt = (($r.'Drivetrain Category' + '').Trim().ToUpper())
    if (-not $market -or -not $model -or -not $dt) { continue }

    $dateVal = [datetime]'1900-01-01'
    $dtxt = ($r.Date + '').Trim()
    if ($dtxt) {
        try { $dateVal = [datetime]$dtxt } catch { }
    }

    $vtxt = ($r.'Value Actual' + '').Trim()
    $val = 0.0
    if (-not [double]::TryParse($vtxt, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$val)) {
        continue
    }

    $baseKey = "${market}_${model}_${dt}"
    $key = "${baseKey}|${kpi}"

    if (-not $latest.ContainsKey($key) -or $dateVal -gt $latest[$key].date) {
        $latest[$key] = @{ date = $dateVal; value = $val }
    }
}

$ratios = @{}
foreach ($k in $latest.Keys) {
    $parts = $k.Split('|')
    $baseKey = $parts[0]
    $kpiName = $parts[1]
    if ($kpiName -ne $iwvvKpi) { continue }

    $paidKey = "${baseKey}|${iwvvPaidKpi}"
    if (-not $latest.ContainsKey($paidKey)) { continue }

    $iwvv = [double]$latest[$k].value
    $iwvvPaid = [double]$latest[$paidKey].value
    if ($iwvvPaid -le 0) { continue }

    $ratios[$baseKey] = [math]::Round($iwvv / $iwvvPaid, 6)
}

$payload = [ordered]@{
    generatedAt = (Get-Date).ToString('s')
    source = 'data/runtime/msf/MSF_IN.csv'
    formula = 'IWVV / IWVV Paid'
    description = 'Latest IWVV to IWVV Paid ratio by normalized market, model, drivetrain'
    keyFormat = 'MARKET_MODEL_DRIVETRAIN'
    ratios = $ratios
}

$payload | ConvertTo-Json -Depth 6 | Set-Content -Path $ratioOut -Encoding UTF8
Write-Output "Generated $ratioOut with $($ratios.Count) keys."