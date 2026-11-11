# Autotiling, as nwg-piotr/autotiling did under sway: whenever a tiling window
# gets focus, set the split direction from its shape, so the next window opens
# beside a wide window and below a tall one. The result is a spiral-like
# layout without pressing mod+e (toggle-tiling-direction) by hand.
#
# set-tiling-direction does nothing when the direction already matches, and
# otherwise works like sway's `split h`/`split v`: it changes the workspace
# direction for a lone window, or wraps the window in a new split container.
# Floating, fullscreen and ignored windows are left alone.
#
# Started by startup_commands and config_reload_commands in config.yaml, so a
# reload starts it if it is not running yet; a second copy exits at once. It
# exits when GlazeWM does (the `glazewm sub` stream ends). Errors go to
# $LogFile.
#
# Keep this file pure ASCII and Windows PowerShell 5.1 compatible.

$ErrorActionPreference = 'Stop'

$LogFile = Join-Path $env:TEMP 'glazewm-autotiling.log'
$SingleInstanceMutexName = 'Local\glazewm-autotiling'

# Held until the process exits; Windows releases it then.
$singleInstance = New-Object System.Threading.Mutex($false, $SingleInstanceMutexName)
if (-not $singleInstance.WaitOne(0)) { exit 0 }

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

function Set-DirectionFromShape($Container) {
    if ($null -eq $Container) { return }
    if ($Container.type -ne 'window') { return }
    if ($Container.state.type -ne 'tiling') { return }

    # Same rule as autotiling: taller than wide splits vertically.
    $direction = 'horizontal'
    if ($Container.height -gt $Container.width) { $direction = 'vertical' }

    Invoke-GlazeWM @('command', '--id', [string]$Container.id, 'set-tiling-direction', $direction) | Out-Null
}

# Each event is one JSON line.
& glazewm sub --events focus_changed | ForEach-Object {
    try {
        $message = $_ | ConvertFrom-Json
        Set-DirectionFromShape $message.data.focusedContainer
    } catch {
        # A short-lived window (a pop-up, a splash screen) can close between
        # getting focus and the command; nothing went wrong then.
        if ($_.Exception.Message -notmatch 'No container found') {
            Write-Log $_.Exception.Message
        }
    }
}
Write-Log ("glazewm sub ended (exit code {0})" -f $LASTEXITCODE)
