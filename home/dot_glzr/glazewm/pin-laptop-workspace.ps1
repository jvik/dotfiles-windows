# Keeps GlazeWM workspace 10 on the laptop's built-in display, wherever that
# display sits in the monitor layout. Started by startup_commands in
# config.yaml; it exits when GlazeWM does (the `glazewm sub` stream ends).
#
# Why a script: bind_to_monitor only takes a monitor index, and GlazeWM
# numbers monitors by position, so the built-in display's index changes with
# every external monitor setup. Rebinding at runtime does not help either:
# update-workspace-config fails for a workspace that is not active, and does
# not move one that is. So this finds the built-in display through WMI and
# moves the workspace there whenever it is activated or the monitors change.
# With an external monitor connected it also creates the workspace there if it
# does not exist yet (GlazeWM only creates workspaces when they are focused).
#
# Keep this file pure ASCII and Windows PowerShell 5.1 compatible.

$ErrorActionPreference = 'Stop'

$WorkspaceName = '10'
$WatchedEvents = @('workspace_activated', 'monitor_added', 'monitor_removed', 'monitor_updated')
$LogFile = Join-Path $env:TEMP 'glazewm-pin-laptop-workspace.log'

# WmiMonitorConnectionParams.VideoOutputTechnology values of built-in panels
# (D3DKMDT_VIDEO_OUTPUT_TECHNOLOGY): INTERNAL, DISPLAYPORT_EMBEDDED, UDI_EMBEDDED.
$BuiltInOutputTechnologies = @([uint32]2147483648, [uint32]11, [uint32]13)

# A WMI InstanceName such as 'DISPLAY\BOE0BFC\4&2ac7733a&0&UID8388688_0' names
# the same device as GlazeWM's devicePath
# '\\?\DISPLAY#BOE0BFC#4&2ac7733a&0&UID8388688#{...}'; return the shared part.
function Get-BuiltInDisplayIds {
    Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorConnectionParams -ErrorAction SilentlyContinue |
        Where-Object { $BuiltInOutputTechnologies -contains [uint32]$_.VideoOutputTechnology } |
        ForEach-Object { ($_.InstanceName -replace '_\d+$', '') -replace '\\', '#' }
}

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

function Get-Monitors {
    return @((Invoke-GlazeWM @('query', 'monitors')).data.monitors)
}

function Find-BuiltInMonitorIndex($Monitors, [string[]]$DisplayIds) {
    for ($i = 0; $i -lt $Monitors.Count; $i++) {
        $path = [string]$Monitors[$i].devicePath
        foreach ($id in $DisplayIds) {
            if ($path.IndexOf($id, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $i }
        }
    }
    return -1
}

function Find-Workspace($Monitors) {
    foreach ($monitor in $Monitors) {
        foreach ($workspace in $monitor.children) {
            if ($workspace.name -eq $WorkspaceName) {
                return [pscustomobject]@{ Id = $workspace.id; Monitor = $monitor }
            }
        }
    }
    return $null
}

# The direction from one monitor to another, by their centres.
function Get-Direction($From, $To) {
    $dx = ($To.x + $To.width / 2) - ($From.x + $From.width / 2)
    $dy = ($To.y + $To.height / 2) - ($From.y + $From.height / 2)
    if ([math]::Abs($dx) -ge [math]::Abs($dy)) {
        if ($dx -gt 0) { return 'right' } else { return 'left' }
    }
    if ($dy -gt 0) { return 'down' } else { return 'up' }
}

function Get-FocusedWorkspaceName {
    foreach ($workspace in @((Invoke-GlazeWM @('query', 'workspaces')).data.workspaces)) {
        if ($workspace.hasFocus) { return [string]$workspace.name }
    }
    return $null
}

# Creates the workspace on the built-in display, then gives focus back to the
# workspace that had it. focus --workspace creates an inactive workspace on the
# focused monitor, so focus the built-in display first.
function New-WorkspaceOnMonitor([int]$Index) {
    $previous = Get-FocusedWorkspaceName
    Invoke-GlazeWM @('command', 'focus', '--monitor', [string]$Index) | Out-Null
    Invoke-GlazeWM @('command', 'focus', '--workspace', $WorkspaceName) | Out-Null
    if ($previous -and ($previous -ne $WorkspaceName)) {
        Invoke-GlazeWM @('command', 'focus', '--workspace', $previous) | Out-Null
    }
}

function Update-WorkspacePlacement {
    $displayIds = @(Get-BuiltInDisplayIds)
    if ($displayIds.Count -eq 0) { return }

    $monitors = Get-Monitors
    $index = Find-BuiltInMonitorIndex $monitors $displayIds
    if ($index -lt 0) { return }

    # With an external monitor connected, the workspace should exist on the
    # built-in display from the start, not only once it is first opened.
    # (keep_alive in config.yaml keeps it from being destroyed when it is empty
    # and another workspace is shown there; without it this would respawn it
    # over that workspace.)
    if (($monitors.Count -gt 1) -and ($null -eq (Find-Workspace $monitors))) {
        New-WorkspaceOnMonitor $index
        $monitors = Get-Monitors
        $index = Find-BuiltInMonitorIndex $monitors $displayIds
        if ($index -lt 0) { return }
    }

    # move-workspace steps one monitor at a time, so allow one step per monitor.
    for ($step = 0; $step -lt $monitors.Count; $step++) {
        $workspace = Find-Workspace $monitors
        $target = $monitors[$index]
        if (($null -eq $workspace) -or ($workspace.Monitor.id -eq $target.id)) { return }

        $direction = Get-Direction $workspace.Monitor $target
        Invoke-GlazeWM @('command', '--id', $workspace.Id, 'move-workspace', '--direction', $direction) | Out-Null

        $monitors = Get-Monitors
        $index = Find-BuiltInMonitorIndex $monitors $displayIds
        if ($index -lt 0) { return }
    }
}

function Write-Log([string]$Message) {
    try {
        Add-Content -LiteralPath $LogFile -Value ("{0:s} {1}" -f (Get-Date), $Message)
    } catch { }
}

function Invoke-Safely {
    try { Update-WorkspacePlacement } catch { Write-Log $_.Exception.Message }
}

Invoke-Safely
# Each event is one JSON line; which event it was does not matter.
& glazewm sub --events @WatchedEvents | ForEach-Object { Invoke-Safely }
Write-Log ("glazewm sub ended (exit code {0})" -f $LASTEXITCODE)
