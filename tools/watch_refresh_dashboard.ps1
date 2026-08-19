param(
    [switch]$SkipMissingDataReport,
    [switch]$RefreshOnly,
    [int]$DebounceSeconds = 2
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

if ($DebounceSeconds -lt 1) {
    throw 'DebounceSeconds must be >= 1.'
}

function Invoke-RefreshPipeline {
    param(
        [switch]$SkipMissing,
        [switch]$NoBuild
    )

    Write-Host ''
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Running refresh pipeline..."

    if ($SkipMissing) {
        & (Join-Path $repoRoot 'tools\refresh_dashboard_data.ps1') -SkipMissingDataReport
    } else {
        & (Join-Path $repoRoot 'tools\refresh_dashboard_data.ps1')
    }

    if (-not $NoBuild) {
        & (Join-Path $repoRoot 'tools\build_self_contained_dashboard.ps1')
    }

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Refresh pipeline complete."
}

function Register-Watcher {
    param(
        [string]$Path,
        [string]$Filter,
        [bool]$IncludeSubdirectories
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $Path
    $watcher.Filter = $Filter
    $watcher.IncludeSubdirectories = $IncludeSubdirectories
    $watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, LastWrite, CreationTime, Size'
    $watcher.EnableRaisingEvents = $true

    return $watcher
}

$watchers = @()
$watchers += Register-Watcher -Path (Join-Path $repoRoot 'source') -Filter '*.*' -IncludeSubdirectories $false
$watchers += Register-Watcher -Path (Join-Path $repoRoot 'data\runtime\web') -Filter '*.*' -IncludeSubdirectories $false
$watchers += Register-Watcher -Path (Join-Path $repoRoot 'data\runtime\msf') -Filter '*.*' -IncludeSubdirectories $false
$watchers += Register-Watcher -Path (Join-Path $repoRoot 'data\runtime\media') -Filter '*.json' -IncludeSubdirectories $false
$watchers += Register-Watcher -Path (Join-Path $repoRoot 'tools\templates') -Filter '*.html' -IncludeSubdirectories $false
$watchers = @($watchers | Where-Object { $_ -ne $null })

if ($watchers.Count -eq 0) {
    throw 'No watch folders available. Check repository structure.'
}

$eventSubscriptions = @()
foreach ($watcher in $watchers) {
    $eventSubscriptions += Register-ObjectEvent -InputObject $watcher -EventName Changed -SourceIdentifier ("watch_changed_" + [guid]::NewGuid())
    $eventSubscriptions += Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier ("watch_created_" + [guid]::NewGuid())
    $eventSubscriptions += Register-ObjectEvent -InputObject $watcher -EventName Renamed -SourceIdentifier ("watch_renamed_" + [guid]::NewGuid())
    $eventSubscriptions += Register-ObjectEvent -InputObject $watcher -EventName Deleted -SourceIdentifier ("watch_deleted_" + [guid]::NewGuid())
}

Write-Host '=== Auto Refresh Watcher ==='
Write-Host "Repository root: $repoRoot"
Write-Host 'Watching:'
$watchers | ForEach-Object { Write-Host ("- " + $_.Path) }
Write-Host ''
Write-Host 'Press Ctrl+C to stop.'

$lastRun = [datetime]::MinValue

try {
    while ($true) {
        $evt = Wait-Event -Timeout 2
        if ($null -eq $evt) {
            continue
        }

        # Drain pending events to avoid duplicate runs on file save bursts.
        Remove-Event -EventIdentifier $evt.EventIdentifier | Out-Null
        while ($nextEvt = Get-Event | Select-Object -First 1) {
            Remove-Event -EventIdentifier $nextEvt.EventIdentifier | Out-Null
        }

        $elapsed = (Get-Date) - $lastRun
        if ($elapsed.TotalSeconds -lt $DebounceSeconds) {
            continue
        }

        $lastRun = Get-Date
        Invoke-RefreshPipeline -SkipMissing:$SkipMissingDataReport -NoBuild:$RefreshOnly
    }
} finally {
    foreach ($sub in $eventSubscriptions) {
        if ($sub) {
            Unregister-Event -SourceIdentifier $sub.Name -ErrorAction SilentlyContinue
            Remove-Job -Id $sub.Id -Force -ErrorAction SilentlyContinue
        }
    }

    foreach ($watcher in $watchers) {
        if ($watcher) {
            $watcher.EnableRaisingEvents = $false
            $watcher.Dispose()
        }
    }
}
