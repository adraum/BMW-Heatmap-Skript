$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $repoRoot 'source\BMW_Media_C1.xlsx'
$msfPath = Join-Path $repoRoot 'data\runtime\msf\MSF_IN.csv'

$outCostPath = Join-Path $repoRoot 'data\runtime\media\cost_per_nvwr_paid.json'
$outMixPath = Join-Path $repoRoot 'data\runtime\media\media_mix_paid_share.json'
$outConversionSharePath = Join-Path $repoRoot 'data\runtime\media\media_cost_conversion_share.json'
$outTotalPath = Join-Path $repoRoot 'data\runtime\media\media_total_cost.json'
$outCsPaidPath = Join-Path $repoRoot 'data\runtime\media\cs_paid_webconversion.json'
$outCsOrganicPath = Join-Path $repoRoot 'data\runtime\media\cs_organic_webconversion.json'

if (-not (Test-Path $sourcePath)) {
    throw "Missing source workbook: $sourcePath"
}

if (-not (Test-Path $msfPath)) {
    throw "Missing MSF runtime CSV: $msfPath"
}

function Convert-ToFloat {
    param(
        $Value
    )

    if ($null -eq $Value) { return $null }

    $text = ($Value.ToString()).Trim()
    if (-not $text) { return $null }

    $number = 0.0
    if ([double]::TryParse($text, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
        return $number
    }

    if ([double]::TryParse($text, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::GetCultureInfo('de-DE'), [ref]$number)) {
        return $number
    }

    return $null
}

function Convert-ToDate {
    param(
        $Value
    )

    if ($null -eq $Value) {
        return [datetime]::MinValue
    }

    if ($Value -is [double] -or $Value -is [float] -or $Value -is [decimal] -or $Value -is [int] -or $Value -is [long]) {
        try {
            return [datetime]::FromOADate([double]$Value)
        } catch {
            return [datetime]::MinValue
        }
    }

    $text = ($Value.ToString()).Trim()
    if (-not $text) {
        return [datetime]::MinValue
    }

    $parsed = [datetime]::MinValue
    if ([datetime]::TryParse($text, [ref]$parsed)) {
        return $parsed
    }

    return [datetime]::MinValue
}

function Get-MarketCode {
    param(
        [string]$Country
    )

    $upper = ($Country + '').Trim().ToUpperInvariant()

    switch ($upper) {
        'BE' { return 'BELU' }
        'LU' { return 'BELU' }
        'BELUX' { return 'BELU' }
        'BELU' { return 'BELU' }
        'UK' { return 'GB' }
        'CH' { return 'DE' }
        default { return $upper }
    }
}

function Get-SeriesCode {
    param(
        [string]$Series
    )

    return (($Series + '').Trim().ToUpperInvariant() -replace '\s+', '')
}

function Get-ModelCode {
    param(
        [string]$Model
    )

    return (($Model + '').Trim().ToUpperInvariant() -replace '\s+', '')
}

function Get-DrivetrainCode {
    param(
        [string]$Drivetrain
    )

    $upper = ($Drivetrain + '').Trim().ToUpperInvariant()

    if (-not $upper) {
        return ''
    }

    if ($upper -eq 'BEV') {
        return 'BEV'
    }

    if ($upper -like '*BEV*' -and $upper -like '*NON*') {
        return 'NON-BEV'
    }

    if ($upper -like '*NON*') {
        return 'NON-BEV'
    }

    if ($upper -like '*ICE*' -or $upper -like '*PHEV*') {
        return 'NON-BEV'
    }

    return $upper
}

function New-ParentFolder {
    param(
        [string]$FilePath
    )

    $dir = Split-Path -Parent $FilePath
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

function Write-JsonFile {
    param(
        [string]$Path,
        $Object
    )

    New-ParentFolder -FilePath $Path

    $json = $Object | ConvertTo-Json -Depth 12
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json, $encoding)
}

function Get-RuntimeDataCount {
    param(
        [string]$Path,
        [string]$DataPropertyName
    )

    if (-not (Test-Path $Path)) {
        return 0
    }

    try {
        $payload = Get-Content -Raw -Encoding UTF8 $Path | ConvertFrom-Json
        $dataProperty = $payload.PSObject.Properties[$DataPropertyName]
        if ($null -eq $dataProperty) {
            return 0
        }

        $bag = $dataProperty.Value
        if ($bag -is [System.Collections.IDictionary]) {
            return [int]$bag.Count
        }

        $properties = @($bag.PSObject.Properties)
        return [int]$properties.Count
    } catch {
        return 0
    }
}

function Test-HasUsableRuntimeMediaData {
    $checks = @(
        @{ Path = $outCostPath; Property = 'ratios' },
        @{ Path = $outMixPath; Property = 'ratios' },
        @{ Path = $outConversionSharePath; Property = 'ratios' },
        @{ Path = $outTotalPath; Property = 'totals' },
        @{ Path = $outCsPaidPath; Property = 'ratios' },
        @{ Path = $outCsOrganicPath; Property = 'ratios' }
    )

    foreach ($check in $checks) {
        $count = Get-RuntimeDataCount -Path $check.Path -DataPropertyName $check.Property
        if ($count -gt 0) {
            return $true
        }
    }

    return $false
}

function Get-SharedStrings {
    param(
        [string]$TempFolder
    )

    $sharedStringsPath = Join-Path $TempFolder 'xl\sharedStrings.xml'
    if (-not (Test-Path $sharedStringsPath)) {
        return @()
    }

    $sharedStringsXml = [xml](Get-Content -Raw $sharedStringsPath -Encoding UTF8)
    $values = @()
    foreach ($item in @($sharedStringsXml.sst.si)) {
        $values += ($item.InnerText + '')
    }

    return $values
}

function Get-ColumnNameFromCellRef {
    param(
        [string]$CellRef
    )

    if (-not $CellRef) {
        return ''
    }

    $match = [regex]::Match($CellRef, '^[A-Z]+')
    if (-not $match.Success) {
        return ''
    }

    return $match.Value
}

function Get-CellText {
    param(
        $Cell,
        [string[]]$SharedStrings
    )

    if ($null -eq $Cell) {
        return ''
    }

    $cellTypeProperty = $Cell.PSObject.Properties['t']
    $cellType = if ($null -ne $cellTypeProperty) { $cellTypeProperty.Value + '' } else { '' }
    switch ($cellType) {
        's' {
            $valueProperty = $Cell.PSObject.Properties['v']
            $index = 0
            $rawValue = if ($null -ne $valueProperty) { $valueProperty.Value + '' } else { '' }
            if ([int]::TryParse($rawValue, [ref]$index) -and $index -ge 0 -and $index -lt $SharedStrings.Count) {
                return $SharedStrings[$index]
            }
            return ''
        }
        'inlineStr' {
            $inlineStringProperty = $Cell.PSObject.Properties['is']
            if ($null -ne $inlineStringProperty) {
                $inlineString = $inlineStringProperty.Value
                if ($null -ne $inlineString.PSObject.Properties['t']) {
                    return $inlineString.t.InnerText
                }

                if ($null -ne $inlineString.PSObject.Properties['r']) {
                    return (@($inlineString.r) | ForEach-Object { $_.t.InnerText }) -join ''
                }
            }
            return ''
        }
        default {
            $valueProperty = $Cell.PSObject.Properties['v']
            if ($null -eq $valueProperty) {
                return ''
            }

            return $valueProperty.Value + ''
        }
    }
}

function Get-RowCellMap {
    param(
        $Row,
        [string[]]$SharedStrings
    )

    $map = @{}
    foreach ($cell in @($Row.c)) {
        $column = Get-ColumnNameFromCellRef -CellRef ($cell.r + '')
        if (-not $column) {
            continue
        }

        $map[$column] = Get-CellText -Cell $cell -SharedStrings $SharedStrings
    }

    return $map
}

function Add-ToModelAggregate {
    param(
        [hashtable]$Aggregate,
        [string]$Model,
        [double]$NvwrValue,
        [double]$IwvvValue,
        [double]$PaidNvwrValue,
        [double]$PaidIvValue
    )

    if (-not $Model) {
        return
    }

    if (-not $Aggregate.ContainsKey($Model)) {
        $Aggregate[$Model] = [ordered]@{
            NvwrAll = 0.0
            IwvvAll = 0.0
            NvwrPaid = 0.0
            IvPaid = 0.0
        }
    }

    $Aggregate[$Model].NvwrAll += $NvwrValue
    $Aggregate[$Model].IwvvAll += $IwvvValue
    $Aggregate[$Model].NvwrPaid += $PaidNvwrValue
    $Aggregate[$Model].IvPaid += $PaidIvValue
}

$tempFolder = $null
$tempXlsxPath = $null

try {
    # XLSX is a ZIP archive. Extract and parse XML directly without any dependencies.
    $tempFolder = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "xlsx_$(Get-Random)")
    $tempXlsxPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "BMW_Media_C1_$([System.Guid]::NewGuid().ToString('N')).xlsx")
    [System.IO.Directory]::CreateDirectory($tempFolder) | Out-Null

    # Work on a temp copy to reduce interference with external processes touching the source file.
    Copy-Item -Path $sourcePath -Destination $tempXlsxPath -Force
    
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($tempXlsxPath, $tempFolder)
    $sharedStrings = Get-SharedStrings -TempFolder $tempFolder
    
    $sheetXmlPath = Join-Path $tempFolder 'xl\worksheets\sheet1.xml'
    if (-not (Test-Path $sheetXmlPath)) {
        throw "Cannot find worksheet XML in XLSX file"
    }
    
    $sheetXml = [xml](Get-Content -Raw $sheetXmlPath -Encoding UTF8)
    $rows = $sheetXml.worksheet.sheetData.row
    
    $latestByKey = @{}
    $rowCount = 0
    
    foreach ($row in $rows) {
        $rowCount++
        if ($rowCount -eq 1) { continue }

        $cells = Get-RowCellMap -Row $row -SharedStrings $sharedStrings

        $country = $cells['A'] + ''
        $series = $cells['C'] + ''
        $model = $cells['D'] + ''
        $drivetrain = $cells['E'] + ''
        
        $marketCode = Get-MarketCode -Country $country
        $seriesCode = Get-SeriesCode -Series $series
        $modelCode = Get-ModelCode -Model $model
        $drivetrainCode = Get-DrivetrainCode -Drivetrain $drivetrain
        
        if (-not $marketCode -or -not $seriesCode -or -not $drivetrainCode) {
            continue
        }

        $dateValue = Convert-ToDate -Value $cells['R']
        $mediaCost = Convert-ToFloat -Value $cells['F']
        $mediaCostConvConsid = Convert-ToFloat -Value $cells['I']
        $mediaCostConversion = Convert-ToFloat -Value $cells['J']
        $ivPaid = Convert-ToFloat -Value $cells['N']
        $nvwrPaid = Convert-ToFloat -Value $cells['P']
        $costPerNvwrPaid = Convert-ToFloat -Value $cells['Q']
        
        if (-not $modelCode) {
            continue
        }

        # Use model-level keys to avoid collisions where multiple models share one series
        # (for example U10 and F39 both map to X2 in Media C1).
        $key = "${marketCode}_${modelCode}_${drivetrainCode}"
        
        if (-not $latestByKey.ContainsKey($key) -or $dateValue -ge $latestByKey[$key].Date) {
            $latestByKey[$key] = [pscustomobject]@{
                Key = $key
                Market = $marketCode
                Model = $modelCode
                Series = $seriesCode
                Drivetrain = $drivetrainCode
                Date = $dateValue
                MediaCost = if ($null -eq $mediaCost) { 0.0 } else { $mediaCost }
                MediaCostConvConsid = if ($null -eq $mediaCostConvConsid) { 0.0 } else { $mediaCostConvConsid }
                MediaCostConversion = if ($null -eq $mediaCostConversion) { 0.0 } else { $mediaCostConversion }
                IvPaid = if ($null -eq $ivPaid) { 0.0 } else { $ivPaid }
                NvwrPaid = if ($null -eq $nvwrPaid) { 0.0 } else { $nvwrPaid }
                CostPerNvwrPaid = if ($null -eq $costPerNvwrPaid) { 0.0 } else { $costPerNvwrPaid }
            }
        }
    }
    
    $sortedKeys = @($latestByKey.Keys | Sort-Object)

    $costRatios = [ordered]@{}
    $mixRatios = [ordered]@{}
    $conversionShareRatios = [ordered]@{}
    $totalCosts = [ordered]@{}

    foreach ($key in $sortedKeys) {
        $row = $latestByKey[$key]

        $costRatios[$key] = [double]$row.CostPerNvwrPaid
        $totalCosts[$key] = [double]$row.MediaCost

        if ($row.MediaCost -gt 0) {
            $mixRatios[$key] = [double](($row.MediaCostConvConsid + $row.MediaCostConversion) / $row.MediaCost)
            $conversionShareRatios[$key] = [double]($row.MediaCostConversion / $row.MediaCost)
        } else {
            $mixRatios[$key] = 0.0
            $conversionShareRatios[$key] = 0.0
        }
    }

    $generatedAt = (Get-Date).ToString('s')

    $costPayload = [ordered]@{
        generatedAt = $generatedAt
        source = 'source/BMW_Media_C1.xlsx'
        description = 'Latest Cost per NVWR Paid by normalized market, model, and drivetrain'
        keyFormat = 'MARKET_MODEL_DT'
        ratios = $costRatios
    }

    $mixPayload = [ordered]@{
        generatedAt = $generatedAt
        source = 'source/BMW_Media_C1.xlsx'
        description = 'Latest paid media share by normalized market, model, and drivetrain. Formula: (Media Cost Conv-Consid + Media Cost Conversion) / Media Cost'
        keyFormat = 'MARKET_MODEL_DT'
        ratios = $mixRatios
    }

    $totalPayload = [ordered]@{
        generatedAt = $generatedAt
        source = 'source/BMW_Media_C1.xlsx'
        description = 'Latest total media cost by normalized market, model, and drivetrain'
        keyFormat = 'MARKET_MODEL_DT'
        totals = $totalCosts
    }

    $conversionSharePayload = [ordered]@{
        generatedAt = $generatedAt
        source = 'source/BMW_Media_C1.xlsx'
        description = 'Latest conversion-only media share by normalized market, model, and drivetrain. Formula: Media Cost Conversion / Media Cost'
        keyFormat = 'MARKET_MODEL_DT'
        ratios = $conversionShareRatios
    }

    $csCountries = @('AT', 'BG', 'CZ', 'GR', 'HU', 'PL', 'RO', 'SI', 'SK')
    $csModelAgg = @{}

    foreach ($key in $sortedKeys) {
        $row = $latestByKey[$key]

        if ($csCountries -notcontains $row.Market) {
            continue
        }

        if (-not $row.Model) {
            continue
        }

        if (-not $csModelAgg.ContainsKey($row.Model)) {
            $csModelAgg[$row.Model] = [ordered]@{
                IvPaid = 0.0
                NvwrPaid = 0.0
            }
        }

        $csModelAgg[$row.Model].IvPaid += [double]$row.IvPaid
        $csModelAgg[$row.Model].NvwrPaid += [double]$row.NvwrPaid
    }

    $csRatios = [ordered]@{}
    foreach ($model in @($csModelAgg.Keys | Sort-Object)) {
        $ivPaidTotal = [double]$csModelAgg[$model].IvPaid
        $nvwrPaidTotal = [double]$csModelAgg[$model].NvwrPaid

        if ($ivPaidTotal -gt 0) {
            $csRatios[$model] = [double]($nvwrPaidTotal / $ivPaidTotal)
        } else {
            $csRatios[$model] = 0.0
        }
    }

    $csPaidPayload = [ordered]@{
        market = 'CS'
        formula = 'NVWR Paid / IV Paid'
        iwvvPaidAlias = 'IV Paid'
        countries = $csCountries
        generatedAt = $generatedAt
        source = 'source/BMW_Media_C1.xlsx'
        ratios = $csRatios
    }

    $msfRows = Import-Csv $msfPath
    $msfLatest = @{}
    $csOrganicModels = @{}
    $csOrganicCountries = @('AT', 'BG', 'CZ', 'GR', 'HU', 'PL', 'RO', 'SI', 'SK')
    $msfKpis = @{
        'New Vehicle Web Requests - All' = 'NvwrAll'
        'Interacting Vehicle Web Visits - All' = 'IwvvAll'
    }

    foreach ($msfRow in $msfRows) {
        $kpi = ($msfRow.KPI + '').Trim()
        if (-not $msfKpis.ContainsKey($kpi)) {
            continue
        }

        $countryCode = (($msfRow.'Country Code' + '').Trim().ToUpperInvariant())
        if ($csOrganicCountries -notcontains $countryCode) {
            continue
        }

        $modelCode = (($msfRow.'Model Range' + '').Trim().ToUpperInvariant())
        $drivetrainCode = Get-DrivetrainCode -Drivetrain ($msfRow.'Drivetrain Category' + '')
        if (-not $modelCode -or -not $drivetrainCode) {
            continue
        }

        $value = Convert-ToFloat -Value $msfRow.'Value Actual'
        if ($null -eq $value) {
            continue
        }

        $dateValue = Convert-ToDate -Value ($msfRow.Date + '')
        $entryKey = "${countryCode}_${modelCode}_${drivetrainCode}|${kpi}"
        if (-not $msfLatest.ContainsKey($entryKey) -or $dateValue -ge $msfLatest[$entryKey].Date) {
            $msfLatest[$entryKey] = [pscustomobject]@{
                Date = $dateValue
                Value = [double]$value
            }
        }
    }

    foreach ($key in $sortedKeys) {
        $row = $latestByKey[$key]
        if ($csOrganicCountries -notcontains $row.Market) {
            continue
        }

        Add-ToModelAggregate -Aggregate $csOrganicModels -Model $row.Model -NvwrValue 0.0 -IwvvValue 0.0 -PaidNvwrValue ([double]$row.NvwrPaid) -PaidIvValue ([double]$row.IvPaid)
    }

    foreach ($entryKey in $msfLatest.Keys) {
        $parts = $entryKey.Split('|', 2)
        if ($parts.Count -ne 2) {
            continue
        }

        $idParts = $parts[0].Split('_')
        if ($idParts.Count -lt 3) {
            continue
        }

        $modelCode = $idParts[1]
        $metric = $msfKpis[$parts[1]]
        $nvwrValue = 0.0
        $iwvvValue = 0.0

        if ($metric -eq 'NvwrAll') {
            $nvwrValue = [double]$msfLatest[$entryKey].Value
        } elseif ($metric -eq 'IwvvAll') {
            $iwvvValue = [double]$msfLatest[$entryKey].Value
        }

        Add-ToModelAggregate -Aggregate $csOrganicModels -Model $modelCode -NvwrValue $nvwrValue -IwvvValue $iwvvValue -PaidNvwrValue 0.0 -PaidIvValue 0.0
    }

    $csOrganicRatios = [ordered]@{}
    foreach ($model in @($csOrganicModels.Keys | Sort-Object)) {
        $totals = $csOrganicModels[$model]
        $organicNvwr = [double]$totals.NvwrAll - [double]$totals.NvwrPaid
        $organicIwvv = [double]$totals.IwvvAll - [double]$totals.IvPaid

        if ($organicNvwr -lt 0) {
            $organicNvwr = 0.0
        }

        if ($organicIwvv -gt 0 -and $organicNvwr -ge 0) {
            $csOrganicRatios[$model] = [double]($organicNvwr / $organicIwvv)
        } else {
            $csOrganicRatios[$model] = 0.0
        }
    }

    $csOrganicPayload = [ordered]@{
        market = 'CS'
        formula = 'sum (NVWR All - NVWR Paid) / sum (IWVV All - IV Paid)'
        countries = $csOrganicCountries
        generatedAt = $generatedAt
        sources = @(
            'data/runtime/msf/MSF_IN.csv',
            'source/BMW_Media_C1.xlsx'
        )
        description = 'Regional organic webconversion fallback for CS derived from latest MSF totals minus latest paid media totals, aggregated by model'
        ratios = $csOrganicRatios
    }

    Write-JsonFile -Path $outCostPath -Object $costPayload
    Write-JsonFile -Path $outMixPath -Object $mixPayload
    Write-JsonFile -Path $outConversionSharePath -Object $conversionSharePayload
    Write-JsonFile -Path $outTotalPath -Object $totalPayload
    Write-JsonFile -Path $outCsPaidPath -Object $csPaidPayload
    Write-JsonFile -Path $outCsOrganicPath -Object $csOrganicPayload

    Write-Host "Generated media JSONs from source/BMW_Media_C1.xlsx"
    Write-Host "- data/runtime/media/cost_per_nvwr_paid.json ($($costRatios.Count) keys)"
    Write-Host "- data/runtime/media/media_mix_paid_share.json ($($mixRatios.Count) keys)"
    Write-Host "- data/runtime/media/media_cost_conversion_share.json ($($conversionShareRatios.Count) keys)"
    Write-Host "- data/runtime/media/media_total_cost.json ($($totalCosts.Count) keys)"
    Write-Host "- data/runtime/media/cs_paid_webconversion.json ($($csRatios.Count) models)"
    Write-Host "- data/runtime/media/cs_organic_webconversion.json ($($csOrganicRatios.Count) models)"

} catch {
    Write-Host "Warning: Could not read Excel file: $_"

    if (Test-HasUsableRuntimeMediaData) {
        Write-Host "Keeping previously generated runtime media JSON files to avoid replacing them with placeholders."
        Write-Host "Resolve workbook lock on source/BMW_Media_C1.xlsx and rerun this script for fresh values."
        return
    }

    Write-Host "No usable existing media JSON data found. Generating placeholder JSON files instead..."
    
    $generatedAt = (Get-Date).ToString('s')
    
    $emptyPayload = [ordered]@{
        generatedAt = $generatedAt
        source = 'source/BMW_Media_C1.xlsx'
        description = 'Placeholder - Excel file could not be read'
        error = $_.Exception.Message
        ratios = @{}
    }
    
    Write-JsonFile -Path $outCostPath -Object $emptyPayload
    Write-JsonFile -Path $outMixPath -Object $emptyPayload
    Write-JsonFile -Path $outConversionSharePath -Object $emptyPayload
    Write-JsonFile -Path $outTotalPath -Object ([ordered]@{
        generatedAt = $generatedAt
        source = 'source/BMW_Media_C1.xlsx'
        description = 'Placeholder - Excel file could not be read'
        error = $_.Exception.Message
        totals = @{}
    })
    Write-JsonFile -Path $outCsPaidPath -Object ([ordered]@{
        market = 'CS'
        generatedAt = $generatedAt
        source = 'source/BMW_Media_C1.xlsx'
        description = 'Placeholder - Excel file could not be read'
        error = $_.Exception.Message
        ratios = @{}
    })
    Write-JsonFile -Path $outCsOrganicPath -Object ([ordered]@{
        market = 'CS'
        generatedAt = $generatedAt
        sources = @(
            'data/runtime/msf/MSF_IN.csv',
            'source/BMW_Media_C1.xlsx'
        )
        description = 'Placeholder - source files could not be read'
        error = $_.Exception.Message
        ratios = @{}
    })
    
    Write-Host "Created placeholder files. Check if BMW_Media_C1.xlsx exists and is not locked by another process."
} finally {
    if ($tempFolder -and (Test-Path $tempFolder)) {
        Remove-Item -Path $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($tempXlsxPath -and (Test-Path $tempXlsxPath)) {
        Remove-Item -Path $tempXlsxPath -Force -ErrorAction SilentlyContinue
    }
}
