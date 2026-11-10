# Opens a newly started app on the workspace it was started from. GlazeWM puts
# a new window on whichever workspace is focused when the window appears, so an
# app that takes a moment to start (from a keybinding or Command Palette, then
# mod+N right after) would otherwise land on the workspace you switched to.
#
# How: this records each time the focused workspace changes. When GlazeWM
# manages a new window, it looks up when the window's process started and which
# workspace was focused then, and moves the window there. Focus stays where you
# are. A window is left alone when:
# - its process started more than $MaxLaunchSeconds ago, or before this script
#   (a new window of an app that was already running, such as a second Firefox
#   window, opens where you are);
# - it did not land on the focused workspace (a window rule placed it, as for
#   Teams and Slack);
# - its process cannot be read (elevated apps), or the process hosts windows
#   for others (UWP apps such as Calculator run under ApplicationFrameHost).
#
# Started by startup_commands in config.yaml; it exits when GlazeWM does (the
# `glazewm sub` stream ends). Errors go to $LogFile.
#
# Keep this file pure ASCII and Windows PowerShell 5.1 compatible.

$ErrorActionPreference = 'Stop'

# Long enough for a slow Electron app to show its first window.
$MaxLaunchSeconds = 20
$LogFile = Join-Path $env:TEMP 'glazewm-open-on-launch-workspace.log'
$WatchedEvents = @('focus_changed', 'window_managed')

Add-Type -Namespace GlazeWmHelpers -Name User32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
'@

# The focused workspace over time, oldest first, as { Time, Workspace }. Only
# changes are recorded, so each entry holds until the next one.
$FocusHistory = New-Object System.Collections.ArrayList

function Write-Log([string]$Message) {
    try {
        Add-Content -LiteralPath $LogFile -Value ("{0:s} {1}" -f (Get-Date), $Message)
    } catch { }
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

function Get-FocusedWorkspaceName {
    foreach ($workspace in @((Invoke-GlazeWM @('query', 'workspaces')).data.workspaces)) {
        if ($workspace.hasFocus) { return [string]$workspace.name }
    }
    return $null
}

# The name of the workspace holding container $Id, or $null. Windows can sit
# in nested split containers, so walk the whole tree under each workspace.
function Find-WindowWorkspace([string]$Id) {
    $monitors = @((Invoke-GlazeWM @('query', 'monitors')).data.monitors)
    foreach ($monitor in $monitors) {
        foreach ($workspace in @($monitor.children)) {
            $stack = New-Object System.Collections.Stack
            foreach ($child in @($workspace.children)) { $stack.Push($child) }
            while ($stack.Count -gt 0) {
                $node = $stack.Pop()
                if ($null -eq $node) { continue }
                if ([string]$node.id -eq $Id) { return [string]$workspace.name }
                foreach ($child in @($node.children)) { $stack.Push($child) }
            }
        }
    }
    return $null
}

function Update-FocusHistory([datetime]$Time) {
    $workspace = Get-FocusedWorkspaceName
    if (-not $workspace) { return }
    $count = $FocusHistory.Count
    if (($count -gt 0) -and ($FocusHistory[$count - 1].Workspace -eq $workspace)) { return }
    [void]$FocusHistory.Add([pscustomobject]@{ Time = $Time; Workspace = $workspace })

    # Drop entries that ended before any process this script still acts on
    # started. The newest entry older than that stays: it was focused then.
    $cutoff = $Time.AddSeconds(-$MaxLaunchSeconds)
    while (($FocusHistory.Count -gt 1) -and ($FocusHistory[1].Time -lt $cutoff)) {
        $FocusHistory.RemoveAt(0)
    }
}

# $null when $Time is before the first entry, i.e. before this script started.
function Get-WorkspaceFocusedAt([datetime]$Time) {
    $workspace = $null
    foreach ($entry in $FocusHistory) {
        if ($entry.Time -gt $Time) { break }
        $workspace = $entry.Workspace
    }
    return $workspace
}

function Get-WindowProcessStartTime($Handle) {
    $processId = [uint32]0
    [void][GlazeWmHelpers.User32]::GetWindowThreadProcessId([IntPtr][int64]$Handle, [ref]$processId)
    if ($processId -eq 0) { return $null }
    try { return (Get-Process -Id $processId).StartTime } catch { return $null }
}

function Move-ToLaunchWorkspace($Window) {
    if ($null -eq $Window) { throw 'window_managed event without managedWindow' }

    $started = Get-WindowProcessStartTime $Window.handle
    if ($null -eq $started) { return }
    if ($started -lt (Get-Date).AddSeconds(-$MaxLaunchSeconds)) { return }

    $launchWorkspace = Get-WorkspaceFocusedAt $started
    $focused = Get-FocusedWorkspaceName
    if ((-not $launchWorkspace) -or ($launchWorkspace -eq $focused)) { return }

    $id = [string]$Window.id
    if ((Find-WindowWorkspace $id) -ne $focused) { return }

    Invoke-GlazeWM @('command', '--id', $id, 'move', '--workspace', $launchWorkspace) | Out-Null
}

try { Update-FocusHistory (Get-Date) } catch { Write-Log $_.Exception.Message }

# Each event is one JSON line.
& glazewm sub --events @WatchedEvents | ForEach-Object {
    # Stamp a focus change as it arrives, not after the query that follows: a
    # launch right after a workspace switch must count as after it.
    $received = Get-Date
    try {
        $message = $_ | ConvertFrom-Json
        if ($message.data.eventType -eq 'window_managed') {
            Move-ToLaunchWorkspace $message.data.managedWindow
        } else {
            Update-FocusHistory $received
        }
    } catch { Write-Log $_.Exception.Message }
}
Write-Log ("glazewm sub ended (exit code {0})" -f $LASTEXITCODE)
