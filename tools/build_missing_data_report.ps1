$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$watchoutsPath = Join-Path $repoRoot 'source\BMW_Watchouts.csv'
$masterPath = Join-Path $repoRoot 'source\BMW_BG26-OI-R.csv'
$topsellersPath = Join-Path $repoRoot 'data\runtime\config\topsellers_per_market.json'
$orgPath = Join-Path $repoRoot 'source\Webconversion-organic.csv'
$paidPath = Join-Path $repoRoot 'source\Webconversion-paid.csv'
$hvnwrPath = Join-Path $repoRoot 'source\HVNWR.csv'
$csOrgPath = Join-Path $repoRoot 'data\runtime\media\cs_organic_webconversion.json'
$csPaidPath = Join-Path $repoRoot 'data\runtime\media\cs_paid_webconversion.json'
$costPath = Join-Path $repoRoot 'data\runtime\media\cost_per_nvwr_paid.json'
$reportOut = Join-Path $repoRoot 'data\generated\reports\missing_data_report_topsellers.csv'
$missingOut = Join-Path $repoRoot 'data\generated\reports\missing_data_only_topsellers.csv'

$watchouts = Import-Csv $watchoutsPath
$master = Import-Csv $masterPath
$topsellers = Get-Content $topsellersPath | ConvertFrom-Json
$orgRows = Import-Csv $orgPath
$paidRows = Import-Csv $paidPath
$hvnwrRows = Import-Csv $hvnwrPath
$csOrg = (Get-Content $csOrgPath | ConvertFrom-Json).ratios
$csPaid = (Get-Content $csPaidPath | ConvertFrom-Json).ratios
$costObj = (Get-Content $costPath | ConvertFrom-Json).ratios
$costKeys = @($costObj.PSObject.Properties.Name)

$countryToMarket = @{
    'AT'='AT'; 'BE'='BELU'; 'BG'='BG'; 'CZ'='CZ'; 'DE'='DE'; 'ES'='ES'; 'FR'='FR'
    'GB'='GB'; 'GR'='GR'; 'HU'='HU'; 'IT'='IT'; 'JP'='JP'; 'KR'='KR'; 'NL'='NL'
    'PL'='PL'; 'RO'='RO'; 'SI'='SI'; 'SK'='SK'; 'CH'='DE'; 'BELUX'='BELU'; 'CS'='CZ'; 'US'='DE'
}

function Resolve-MarketCode([string]$countryCode) {
    $k = ($countryCode + '').Trim().ToUpper()
    if ($countryToMarket.ContainsKey($k)) { return $countryToMarket[$k] }
    return $k
}

function Build-MarketModelMap($rows) {
    $map = @{}
    if (-not $rows -or $rows.Count -eq 0) { return $map }

    $headers = @($rows[0].PSObject.Properties.Name)
    $modelCol = if ($headers -contains '') { '' } elseif ($headers -contains 'Model Range') { 'Model Range' } else { $headers[0] }
    $marketCols = @('AT','BELU','BG','CZ','DE','ES','FR','GB','GR','HU','IT','JP','KR','NL','PL','RO','SI','SK')

    foreach ($row in $rows) {
        $model = (($row.$modelCol + '').Trim().ToUpper())
        if (-not $model -or $model.Length -gt 5) { continue }
        if ($model -like '*NEW VEHICLE*' -or $model -like '*NVWR*') { continue }

        foreach ($mc in $marketCols) {
            if (-not ($row.PSObject.Properties.Name -contains $mc)) { continue }
            $vtxt = (($row.$mc + '').Trim())
            if (-not $vtxt) { continue }
            $v = 0.0
            if ([double]::TryParse($vtxt, [ref]$v)) {
                $map["${mc}_${model}"] = $v
            }
        }
    }

    return $map
}

$modelToSeries = @{}
foreach ($m in $master) {
    $model = (($m.'Model Range' + '').Trim().ToUpper())
    $series = (($m.Series + '').Trim().ToUpper())
    if (-not $model -or -not $series) { continue }
    if (-not $modelToSeries.ContainsKey($model)) { $modelToSeries[$model] = @() }
    if ($modelToSeries[$model] -notcontains $series) { $modelToSeries[$model] += $series }
}

$orgMap = Build-MarketModelMap $orgRows
$paidMap = Build-MarketModelMap $paidRows
$hvnwrMap = Build-MarketModelMap $hvnwrRows

$rowsOut = @()
foreach ($w in $watchouts) {
    $market = (($w.country_code + '').Trim().ToUpper())
    $model = (($w.'Model Range' + '').Trim().ToUpper())
    $dt = (($w.'Drivetrain Category' + '').Trim().ToUpper())
    if (-not $market -or -not $model -or -not $dt) { continue }

    if (-not ($topsellers.PSObject.Properties.Name -contains $market)) { continue }
    $combo = "${model}-${dt}"
    if (@($topsellers.$market.topsellers) -notcontains $combo) { continue }

    $norm = Resolve-MarketCode $market

    if ($market -eq 'CS') {
        $orgAvail = $csOrg.PSObject.Properties.Name -contains $model
        $paidAvail = $csPaid.PSObject.Properties.Name -contains $model
    } else {
        $orgAvail = $orgMap.ContainsKey("${norm}_${model}")
        $paidAvail = $paidMap.ContainsKey("${norm}_${model}")
    }

    $hvnwrAvail = $hvnwrMap.ContainsKey("${norm}_${model}")

    $cands = @()
    if ($modelToSeries.ContainsKey($model)) {
        foreach ($series in $modelToSeries[$model]) {
            $raw = ($series + '').Trim().ToUpper()
            $compact = $raw -replace '\s+', ''
            $noSuffix = ($raw -replace '\s+SERIES$', '').Trim()
            $compactNo = $noSuffix -replace '\s+', ''

            foreach ($x in @($raw, $compact, $noSuffix, $compactNo)) {
                if ($x -and $cands -notcontains $x) { $cands += $x }
            }

            if ($dt -eq 'BEV') {
                if ($compactNo.StartsWith('X') -and -not $compactNo.StartsWith('IX')) {
                    $ix = 'I' + $compactNo
                    if ($cands -notcontains $ix) { $cands += $ix }
                }
                if ($compactNo -match '^[1-8]$') {
                    $iSeries = 'I' + $compactNo
                    if ($cands -notcontains $iSeries) { $cands += $iSeries }
                }
            }
        }
    }

    if ($cands -notcontains $model) { $cands += $model }

    $costKey = ''
    foreach ($s in $cands) {
        $k = "${norm}_${s}_${dt}"
        if ($costKeys -contains $k) {
            $costKey = $k
            break
        }
    }
    $costAvail = [bool]$costKey

    $rowsOut += [pscustomobject]@{
        Market = $market
        Model = $model
        Drivetrain = $dt
        OrganicAvailable = $orgAvail
        PaidAvailable = $paidAvail
        HVNWRAvailable = $hvnwrAvail
        CostPerNVWRAvailable = $costAvail
        CostKeyMatched = $costKey
    }
}

$rowsOut = $rowsOut | Sort-Object Market, Model, Drivetrain -Unique
$missing = $rowsOut | Where-Object { -not $_.OrganicAvailable -or -not $_.PaidAvailable -or -not $_.HVNWRAvailable -or -not $_.CostPerNVWRAvailable }

$rowsOut | Export-Csv $reportOut -NoTypeInformation -Encoding UTF8
$missing | Export-Csv $missingOut -NoTypeInformation -Encoding UTF8

Write-Output "Scoped topseller combos: $($rowsOut.Count)"
Write-Output "Missing combos: $($missing.Count)"
Write-Output "Organic missing: $((@($rowsOut | Where-Object { -not $_.OrganicAvailable })).Count)"
Write-Output "Paid missing: $((@($rowsOut | Where-Object { -not $_.PaidAvailable })).Count)"
Write-Output "HVNWR missing: $((@($rowsOut | Where-Object { -not $_.HVNWRAvailable })).Count)"
Write-Output "Cost missing: $((@($rowsOut | Where-Object { -not $_.CostPerNVWRAvailable })).Count)"
