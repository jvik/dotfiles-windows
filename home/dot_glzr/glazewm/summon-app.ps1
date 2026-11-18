# Brings an app's window to the focused workspace, or sends it away again. A
# stand-in for sway's scratchpad, which GlazeWM lacks. config.yaml binds it to
# lwin+shift+t (Teams), lwin+shift+s (Slack) and lwin+shift+o (Obsidian).
#
# - The window is on another workspace, or minimized: move it to the focused
#   one, restore it and focus it.
# - It is already on the focused workspace: send it back to -HomeWorkspace
#   (a window rule in config.yaml opens it there too). On the home workspace
#   itself it is only focused. With -Minimize it is minimized instead, which
#   hides it the way sway's scratchpad did; -HomeWorkspace is then unused.
# - No window (not running, or closed to the tray): open -LaunchUri (a URI or
#   a program path) and bring the window here once GlazeWM manages it.
#
# -ProcessNames is a comma-separated list, since apps can go by more than one
# name (new Teams is ms-teams, classic Teams is Teams).
#
# Errors go to $LogFile. Keep this file pure ASCII and Windows PowerShell 5.1
# compatible.

param(
    [Parameter(Mandatory = $true)][string]$ProcessNames,
    [Parameter(Mandatory = $true)][string]$LaunchUri,
    [string]$HomeWorkspace = '4',
    [switch]$Minimize
)

$ErrorActionPreference = 'Stop'

$LaunchTimeoutSeconds = 15
$LogFile = Join-Path $env:TEMP 'glazewm-summon-app.log'
$Names = @($ProcessNames -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

function Write-Log([string]$Message) {
    try {
        Add-Content -LiteralPath $LogFile -Value ("{0:s} [{1}] {2}" -f (Get-Date), $ProcessNames, $Message)
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

# The first managed window of the app as { Id, Workspace, State }, or $null.
# Windows can sit in nested split containers, so walk the whole tree under
# each workspace. -contains compares case-insensitively.
function Find-AppWindow {
    $monitors = @((Invoke-GlazeWM @('query', 'monitors')).data.monitors)
    foreach ($monitor in $monitors) {
        foreach ($workspace in @($monitor.children)) {
            $stack = New-Object System.Collections.Stack
            foreach ($child in @($workspace.children)) { $stack.Push($child) }
            while ($stack.Count -gt 0) {
                $node = $stack.Pop()
                if ($null -eq $node) { continue }
                if (($null -ne $node.handle) -and ($Names -contains [string]$node.processName)) {
                    return [pscustomobject]@{
                        Id        = [string]$node.id
                        Workspace = [string]$workspace.name
                        State     = [string]$node.state.type
                    }
                }
                foreach ($child in @($node.children)) { $stack.Push($child) }
            }
        }
    }
    return $null
}

function Get-FocusedWorkspaceName {
    foreach ($workspace in @((Invoke-GlazeWM @('query', 'workspaces')).data.workspaces)) {
        if ($workspace.hasFocus) { return [string]$workspace.name }
    }
    return $null
}

function Open-App {
    Start-Process $LaunchUri
    $deadline = (Get-Date).AddSeconds($LaunchTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 250
        $window = Find-AppWindow
        if ($null -ne $window) { return $window }
    }
    throw ("no window appeared within {0} s" -f $LaunchTimeoutSeconds)
}

function Invoke-SummonApp {
    $current = Get-FocusedWorkspaceName
    if (-not $current) { throw 'no focused workspace' }

    $window = Find-AppWindow
    if ($null -eq $window) {
        $window = Open-App
    } elseif (($window.Workspace -eq $current) -and ($window.State -ne 'minimized')) {
        if ($Minimize) {
            Invoke-GlazeWM @('command', '--id', $window.Id, 'set-minimized') | Out-Null
            return
        }
        if ($current -ne $HomeWorkspace) {
            Invoke-GlazeWM @('command', '--id', $window.Id, 'move', '--workspace', $HomeWorkspace) | Out-Null
            return
        }
    }

    if ($window.Workspace -ne $current) {
        Invoke-GlazeWM @('command', '--id', $window.Id, 'move', '--workspace', $current) | Out-Null
    }
    # Back to the state it had before (tiling or floating).
    if ($window.State -eq 'minimized') {
        Invoke-GlazeWM @('command', '--id', $window.Id, 'toggle-minimized') | Out-Null
    }
    Invoke-GlazeWM @('command', 'focus', '--container-id', $window.Id) | Out-Null
}

try { Invoke-SummonApp } catch { Write-Log $_.Exception.Message }
