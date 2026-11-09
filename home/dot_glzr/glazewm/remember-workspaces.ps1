# Remembers which workspace each window is on, so a GlazeWM restart puts the
# windows back. On its own GlazeWM keeps no state: after a restart every open
# window lands on the workspace that is showing. (A config reload,
# lwin+ctrl+shift+c, keeps everything and does not need this.)
#
# How: a window's handle (hwnd) survives a GlazeWM restart. While GlazeWM runs,
# this records hwnd -> workspace in $StateFile on every window event. At
# startup it moves each window it knows back to its workspace. Only the
# workspace is restored, not the split layout or sizes within it.
#
# An entry is dropped once its window is closed (not merely when GlazeWM stops
# managing it, as happens when GlazeWM exits). The process name is stored too,
# so a reused hwnd after a reboot does not move some other app.
#
# Started by startup_commands in config.yaml; it exits when GlazeWM does (the
# `glazewm sub` stream ends). Errors go to $LogFile.
#
# Keep this file pure ASCII and Windows PowerShell 5.1 compatible.

$ErrorActionPreference = 'Stop'

$StateFile = Join-Path $env:LOCALAPPDATA 'glazewm-window-workspaces.json'
$LogFile = Join-Path $env:TEMP 'glazewm-remember-workspaces.log'
$WatchedEvents = @('window_managed', 'window_unmanaged', 'focus_changed', 'focused_container_moved', 'workspace_activated')

Add-Type -Namespace GlazeWmHelpers -Name User32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
'@

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

# Every managed window as { Id, Handle, Process, Workspace }. Windows can sit in
# nested split containers, so walk the whole tree under each workspace.
function Get-ManagedWindows {
    $windows = New-Object System.Collections.ArrayList
    $monitors = @((Invoke-GlazeWM @('query', 'monitors')).data.monitors)
    foreach ($monitor in $monitors) {
        foreach ($workspace in @($monitor.children)) {
            $stack = New-Object System.Collections.Stack
            foreach ($child in @($workspace.children)) { $stack.Push($child) }
            while ($stack.Count -gt 0) {
                $node = $stack.Pop()
                if ($null -eq $node) { continue }
                if ($null -ne $node.handle) {
                    [void]$windows.Add([pscustomobject]@{
                        Id        = [string]$node.id
                        Handle    = [string]$node.handle
                        Process   = [string]$node.processName
                        Workspace = [string]$workspace.name
                    })
                }
                foreach ($child in @($node.children)) { $stack.Push($child) }
            }
        }
    }
    return $windows
}

# hwnd (string) -> @{ Process; Workspace }
function Read-State {
    $state = @{}
    if (Test-Path -LiteralPath $StateFile) {
        try {
            $json = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
            foreach ($p in $json.PSObject.Properties) {
                $state[$p.Name] = @{ Process = [string]$p.Value.Process; Workspace = [string]$p.Value.Workspace }
            }
        } catch { Write-Log ("could not read {0}: {1}" -f $StateFile, $_.Exception.Message) }
    }
    return $state
}

function Save-State {
    $state = Read-State
    foreach ($w in Get-ManagedWindows) {
        $state[$w.Handle] = @{ Process = $w.Process; Workspace = $w.Workspace }
    }
    foreach ($handle in @($state.Keys)) {
        if (-not [GlazeWmHelpers.User32]::IsWindow([IntPtr][int64]$handle)) { $state.Remove($handle) }
    }
    $tmp = "$StateFile.tmp"
    ConvertTo-Json -InputObject $state -Depth 3 | Set-Content -LiteralPath $tmp -Encoding ASCII
    Move-Item -LiteralPath $tmp -Destination $StateFile -Force
}

function Restore-Workspaces {
    $state = Read-State
    if ($state.Count -eq 0) { return }
    foreach ($w in Get-ManagedWindows) {
        $saved = $state[$w.Handle]
        if (($null -eq $saved) -or ($saved.Process -ne $w.Process) -or ($saved.Workspace -eq $w.Workspace)) { continue }
        try {
            Invoke-GlazeWM @('command', '--id', $w.Id, 'move', '--workspace', $saved.Workspace) | Out-Null
        } catch { Write-Log $_.Exception.Message }
    }
}

# GlazeWM manages the windows that are already open as it starts; give it a
# moment so they are all in the tree before they are moved.
Start-Sleep -Seconds 2
try { Restore-Workspaces } catch { Write-Log $_.Exception.Message }
try { Save-State } catch { Write-Log $_.Exception.Message }

# Each event is one JSON line; which event it was does not matter.
& glazewm sub --events @WatchedEvents | ForEach-Object {
    try { Save-State } catch { Write-Log $_.Exception.Message }
}
Write-Log ("glazewm sub ended (exit code {0})" -f $LASTEXITCODE)
