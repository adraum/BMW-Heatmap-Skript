# Analyze topseller models per market (70% of retail budget rule)
$repoRoot = Split-Path -Parent $PSScriptRoot
$masterPath = Join-Path $repoRoot 'source\BMW_BG26-OI-R.csv'
$topsellerOut = Join-Path $repoRoot 'data\runtime\config\topsellers_per_market.json'
$csv = Import-Csv $masterPath

# Markets to analyze (CS = AT+CEEU, mapped as AT for analysis; BELUX = BE+LU)
$markets = @("DE", "GB", "IT", "FR", "BELUX", "NL", "ES", "JP", "KR", "US", "CS")

# Mapping for multi-country markets
$marketMapping = @{
    "CS" = @("AT", "BG", "CZ", "GR", "HU", "PL", "RO", "SI", "SK")  # Central Eastern European markets + Austria
    "BELUX" = @("BE", "LU")  # BELUX is combination of BE and LU
}

# KPI selection per market: "Order Intake" for EU markets, "Retail" for others
$marketKPI = @{
    "DE" = "Order Intake - All"
    "GB" = "Order Intake - All"
    "IT" = "Order Intake - All"
    "FR" = "Order Intake - All"
    "BELUX" = "Order Intake - All"
    "NL" = "Order Intake - All"
    "ES" = "Order Intake - All"
    "CS" = "Order Intake - All"
    "JP" = "Retail - All"
    "KR" = "Retail - All"
    "US" = "Retail - All"
}

# Dictionary to store topsellers per market (Model-Drivetrain combinations)
$topsellersPerMarket = @{}

# For each market, find topsellers that sum to 70% of retail budget
foreach ($market in $markets) {
    # Map market code if needed (e.g., CS -> AT, BELUX -> @(BE, LU))
    $lookupMarkets = @()
    if ($marketMapping.ContainsKey($market)) {
        $mapped = $marketMapping[$market]
        if ($mapped -is [array]) {
            $lookupMarkets = $mapped
        } else {
            $lookupMarkets = @($mapped)
        }
    } else {
        $lookupMarkets = @($market)
    }
    
    # Determine KPI for this market
    $kpi = if ($marketKPI.ContainsKey($market)) { $marketKPI[$market] } else { "Retail - All" }
    
    # Filter data for this market and KPI Benchmark (from all lookupMarkets)
    $marketData = $csv | Where-Object { 
        ($lookupMarkets -contains $_."Country Code") -and 
        $_."KPI" -eq $kpi -and 
        $_."Benchmark" -and
        $_."Model Range"
    }
    
    if ($marketData.Count -eq 0) {
        Write-Host "`n=== MARKET: $market (no data - lookupMarkets: $($lookupMarkets -join ','), KPI: $kpi) ===" 
        continue
    }
    
    # Group by Model Range + Drivetrain and sum benchmarks
    $grouped = $marketData | Group-Object -Property @("Model Range", "Drivetrain Category") | ForEach-Object {
        $total = 0
        $_.Group | ForEach-Object { 
            if ($_."Benchmark") {
                $val = [double]($_."Benchmark" -replace ",", ".")
                $total += $val
            }
        }
        [PSCustomObject]@{
            ModelDrivetrain = "$($_.Name -split ", " | Select-Object -First 1)-$($_.Name -split ", " | Select-Object -Last 1)"
            Model = $_.Name -split ", " | Select-Object -First 1
            Drivetrain = $_.Name -split ", " | Select-Object -Last 1
            Total = $total
        }
    } | Sort-Object -Property Total -Descending
    
    # Calculate total budget
    $totalBudget = ($grouped | Measure-Object -Property Total -Sum).Sum
    
    if ($totalBudget -gt 0) {
        # Find topsellers that sum to 70%, excluding U06, G65, and G06
        $target = $totalBudget * 0.7
        $accumulated = 0
        $topsellers = @()
        $excludedModels = @("U06", "G65", "G06")
        
        foreach ($item in $grouped) {
            # Skip excluded models (U06, G65, G06)
            if ($excludedModels -contains $item.Model) {
                continue
            }
            
            if ($accumulated -lt $target) {
                $topsellers += $item
                $accumulated += $item.Total
            }
        }
        
        # If we haven't reached 70% even after excluding U06/G65/G06, continue adding models
        if ($accumulated -lt $target) {
            foreach ($item in $grouped) {
                if ($topsellers -notcontains $item -and $accumulated -lt $target) {
                    $topsellers += $item
                    $accumulated += $item.Total
                }
            }
        }
        
        # Store for output - preserve drivetrain info
        $topsellersPerMarket[$market] = @{
            Topsellers = $topsellers
            TotalBudget = $totalBudget
            Target = $target
            Accumulated = $accumulated
            AllModels = $grouped
            KPI = $kpi
        }
        
        Write-Host "`n=== MARKET: $market (KPI: $kpi) ===" 
        Write-Host "Total Budget: $([Math]::Round($totalBudget, 0))"
        Write-Host "70% Target: $([Math]::Round($target, 0))"
        Write-Host "Topsellers: $($topsellers.Count) model-drivetrain combinations (excl. U06, G65, G06)"
        Write-Host "Cumulative: $([Math]::Round($accumulated, 0)) ($([Math]::Round(100*$accumulated/$totalBudget, 1))%)"
        Write-Host "`nModel-Drivetrain Combinations:"
        $topsellers | ForEach-Object { 
            Write-Host "  $($_.ModelDrivetrain): $([Math]::Round($_.Total, 0))" 
        }
    }
}

# Export to JSON for dashboard integration - convert topsellers to simple array of Model-Drivetrain strings
$exportData = @{}
foreach ($market in $topsellersPerMarket.Keys) {
    $exportData[$market] = @{
        topsellers = @($topsellersPerMarket[$market].Topsellers | ForEach-Object { "$($_.Model)-$($_.Drivetrain)" })
        count = $topsellersPerMarket[$market].Topsellers.Count
        budget = [Math]::Round($topsellersPerMarket[$market].TotalBudget, 0)
        coverage = [Math]::Round(100*$topsellersPerMarket[$market].Accumulated/$topsellersPerMarket[$market].TotalBudget, 1)
    }
}

$exportData | ConvertTo-Json | Set-Content $topsellerOut

Write-Host "`n`n=== SUMMARY ===" 
Write-Host "Topsellers per market saved to: $topsellerOut"
Write-Host "Format: Market -> Array of Model-Drivetrain combinations (e.g., 'U11-NON-BEV')"
Write-Host ""
foreach ($market in ($exportData.Keys | Sort-Object)) {
    $count = $exportData[$market].count
    $coverage = $exportData[$market].coverage
    Write-Host "${market}: ${count} combinations, $coverage% coverage"
}
