# Restarts Zebar when a display change has left its bar without reserved
# screen space. Started by startup_commands in config.yaml; it exits when
# GlazeWM does (the `glazewm sub` stream ends).
#
# Why: Zebar's bar (dockToEdge in zebar/topbar/zpack.json) is an app bar,
# which keeps windows out of its strip of the screen. When a monitor is
# connected or disconnected, Windows recalculates every monitor's work area
# and asks each app bar to claim its space again; Zebar (v3.3.1) only claims
# it once, when the bar is created, so afterwards the work area is the whole
# screen and GlazeWM tiles windows over the bar. A restart claims it again.
#
# Only restarts when a monitor's work area really starts at its top edge, so
# the monitor_updated event from Zebar's own claim does not restart it again.
#
# Keep this file pure ASCII and Windows PowerShell 5.1 compatible.

$ErrorActionPreference = 'Stop'

$WatchedEvents = @('monitor_added', 'monitor_removed', 'monitor_updated')
$LogFile = Join-Path $env:TEMP 'glazewm-restart-zebar.log'
# Zebar creates and docks the bar of a newly connected monitor on its own;
# give it this long before deciding it did not.
$SettleSeconds = 3

# The CLI can exit 0 for a failed command; the reply's `success` says so.
function Invoke-GlazeWM([string[]]$Arguments) {
    $output = & glazewm @Arguments | Out-String
    $reply = $null
    if ($LASTEXITCODE -eq 0) {
        try { $reply = $output | ConvertFrom-Json } catch { }
    }
    if (($null -eq $reply) -or (-not $reply.success)) {
        throw ("glazewm {0} failed: {1}" -f ($Arguments -join ' '), $output.Trim())
    }
    return $reply
}

# Monitors whose work area reaches their top edge, i.e. have no bar docked.
function Get-UndockedMonitors {
    $monitors = @((Invoke-GlazeWM @('query', 'monitors')).data.monitors)
    return @($monitors | Where-Object { $_.workingRect.top -le $_.y })
}

function Write-Log([string]$Message) {
    try {
        Add-Content -LiteralPath $LogFile -Value ("{0:s} {1}" -f (Get-Date), $Message)
    } catch { }
}

function Repair-Zebar {
    # Not running: it was closed on purpose, or GlazeWM is shutting down.
    if (-not (Get-Process zebar -ErrorAction SilentlyContinue)) { return }

    Start-Sleep -Seconds $SettleSeconds
    $undocked = @(Get-UndockedMonitors)
    if ($undocked.Count -eq 0) { return }

    Write-Log ("no bar space on {0}; restarting Zebar" -f (($undocked | ForEach-Object { $_.devicePath }) -join ', '))
    Stop-Process -Name zebar -Force -ErrorAction SilentlyContinue
    Wait-Process -Name zebar -Timeout 10 -ErrorAction SilentlyContinue
    Start-Process zebar
}

function Invoke-Safely {
    try { Repair-Zebar } catch { Write-Log $_.Exception.Message }
}

# Each event is one JSON line; which event it was does not matter.
& glazewm sub --events @WatchedEvents | ForEach-Object { Invoke-Safely }
Write-Log ("glazewm sub ended (exit code {0})" -f $LASTEXITCODE)
