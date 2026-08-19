# Clean webconversion CSVs - extract only market header and data rows
 
param(
    [string]$InputFile,
    [string]$OutputFile
)

$lines = Get-Content $InputFile
$headerRowIndex = -1
$headerRow = @()
$dataRows = @()

# Find the header row that contains market codes
foreach ($i in 0..($lines.Length - 1)) {
    $line = $lines[$i]
    
    # Check if this line contains market codes
    if ($line -match ',DE,' -or $line -match '^,.*DE,' -or $line -match 'DE,GB,IT') {
        $headerRowIndex = $i
        $headerRow = $line -split ','
        break
    }
}

if ($headerRowIndex -lt 0) {
    Write-Host "No market header found in $InputFile"
    exit 1
}

Write-Host "Found header at line $($headerRowIndex + 1): $($headerRow[0..3] -join ',')"

# Extract data rows
for ($i = $headerRowIndex + 1; $i -lt $lines.Length; $i++) {
    $line = $lines[$i].Trim()
    if ($line -and -not $line.StartsWith('#')) {
        $cols = $line -split ','
        # Check if first column looks like a model code (e.g., F70, G05)
        if ($cols[0] -match '^[A-Z][0-9]{2}$') {
            $dataRows += $line
        }
    }
}

# Write output
$output = @($lines[$headerRowIndex]) + $dataRows
$output | Out-File $OutputFile -Encoding UTF8

Write-Host "Created $OutputFile with $($dataRows.Length) data rows"
