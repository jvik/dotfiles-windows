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
# Lost windows: GlazeWM hides the windows of other workspaces by cloaking
# them, and only a clean exit uncloaks them. After a crash they stay cloaked,
# and the next GlazeWM skips them (it only manages visible windows), so they
# are gone from every workspace until clicked in the taskbar. At startup this
# uncloaks them first, so they get managed and go back to their workspace with
# the rest.
#
# -ShowLostWindows (lwin+shift+m in config.yaml) does that without a restart,
# restores every minimized window as well, and exits.
#
# An entry is dropped once its window is closed (not merely when GlazeWM stops
# managing it, as happens when GlazeWM exits). The process name is stored too,
# so a reused hwnd after a reboot does not move some other app.
#
# Started by startup_commands in config.yaml; it exits when GlazeWM does (the
# `glazewm sub` stream ends). Errors go to $LogFile.
#
# Keep this file pure ASCII and Windows PowerShell 5.1 compatible.

param(
    [switch]$ShowLostWindows
)

$ErrorActionPreference = 'Stop'

$StateFile = Join-Path $env:LOCALAPPDATA 'glazewm-window-workspaces.json'
$LogFile = Join-Path $env:TEMP 'glazewm-remember-workspaces.log'
$WatchedEvents = @('window_managed', 'window_unmanaged', 'focus_changed', 'focused_container_moved', 'workspace_activated')
$ReadAttempts = 5
$ReadRetryMilliseconds = 200
$ManageTimeoutSeconds = 5

# Uncloak calls the same undocumented shell interfaces GlazeWM cloaks windows
# with (packages/wm-platform/src/platform_impl/windows/com.rs in GlazeWM).
# Only the vtable slots up to the method that is called are declared; the M*
# methods are placeholders that keep the layout and are never called.
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

namespace GlazeWmHelpers {
    [ComImport, Guid("6D5140C1-7436-11CE-8034-00AA006009FA"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IShellServiceProvider {
        [PreserveSig] int QueryService(ref Guid service, ref Guid riid, [MarshalAs(UnmanagedType.IUnknown)] out object result);
    }

    [ComImport, Guid("1841C6D7-4F9D-42C0-AF41-8747538F10E5"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IApplicationViewCollection {
        void M1(); void M2(); void M3();
        [PreserveSig] int GetViewForHwnd(IntPtr hwnd, out IApplicationView view);
    }

    [ComImport, Guid("372E1D3B-38D3-42E4-A15B-8AB2B178F513"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IApplicationView {
        void M1(); void M2(); void M3(); void M4(); void M5(); void M6(); void M7(); void M8(); void M9();
        [PreserveSig] int SetCloak(uint cloakType, int cloakFlag);
    }

    public static class NativeWindows {
        const int GWL_EXSTYLE = -20;
        const int WS_EX_TOOLWINDOW = 0x80;
        const uint GW_OWNER = 4;
        const int DWMWA_CLOAKED = 14;
        const int DWM_CLOAKED_SHELL = 2;
        static readonly Guid ImmersiveShellClsid = new Guid("C2F03A33-21F5-47FA-B4BB-156362A2F239");
        // Windows keeps some windows of Store apps (Settings, the touch
        // keyboard) cloaked while the app is suspended or closed.
        static readonly string[] StoreAppClasses = { "ApplicationFrameWindow", "Windows.UI.Core.CoreWindow" };

        delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);
        [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
        [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hwnd);
        [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
        [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr hwnd, uint command);
        [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr hwnd, int index);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hwnd, StringBuilder name, int maxCount);
        [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr hwnd, int attribute, out int value, int size);

        // Top-level app windows that are shown but cloaked by the shell, the
        // way GlazeWM hides windows.
        public static IntPtr[] GetShellCloakedAppWindows() {
            List<IntPtr> found = new List<IntPtr>();
            EnumWindows((hwnd, lParam) => {
                if (IsShellCloakedAppWindow(hwnd)) { found.Add(hwnd); }
                return true;
            }, IntPtr.Zero);
            return found.ToArray();
        }

        static bool IsShellCloakedAppWindow(IntPtr hwnd) {
            if (!IsWindowVisible(hwnd) || GetWindow(hwnd, GW_OWNER) != IntPtr.Zero) { return false; }
            if ((GetWindowLong(hwnd, GWL_EXSTYLE) & WS_EX_TOOLWINDOW) != 0) { return false; }
            int cloaked;
            if (DwmGetWindowAttribute(hwnd, DWMWA_CLOAKED, out cloaked, sizeof(int)) != 0 || cloaked != DWM_CLOAKED_SHELL) { return false; }
            StringBuilder className = new StringBuilder(256);
            GetClassName(hwnd, className, className.Capacity);
            return Array.IndexOf(StoreAppClasses, className.ToString()) < 0;
        }

        // GlazeWM cloaks with SetCloak(1, 2) and uncloaks with SetCloak(1, 0).
        public static void Uncloak(IntPtr hwnd) {
            IShellServiceProvider shell = (IShellServiceProvider)Activator.CreateInstance(Type.GetTypeFromCLSID(ImmersiveShellClsid));
            Guid collectionId = typeof(IApplicationViewCollection).GUID;
            object collection;
            Marshal.ThrowExceptionForHR(shell.QueryService(ref collectionId, ref collectionId, out collection));
            IApplicationView view;
            Marshal.ThrowExceptionForHR(((IApplicationViewCollection)collection).GetViewForHwnd(hwnd, out view));
            Marshal.ThrowExceptionForHR(view.SetCloak(1, 0));
        }
    }
}
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

# Every managed window as { Id, Handle, Process, Workspace, State }. Windows
# can sit in nested split containers, so walk the whole tree under each
# workspace.
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
                        State     = [string]$node.state.type
                    })
                }
                foreach ($child in @($node.children)) { $stack.Push($child) }
            }
        }
    }
    return $windows
}

# hwnd (string) -> @{ Process; Workspace }. Another process can hold the file
# for a moment (a virus scan of the new file), so retry before giving up.
function Read-StateFile {
    $state = @{}
    if (-not (Test-Path -LiteralPath $StateFile)) { return $state }
    for ($attempt = 1; ; $attempt++) {
        try {
            $json = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
            break
        } catch {
            if ($attempt -ge $ReadAttempts) { throw ("could not read {0}: {1}" -f $StateFile, $_.Exception.Message) }
            Start-Sleep -Milliseconds $ReadRetryMilliseconds
        }
    }
    foreach ($p in $json.PSObject.Properties) {
        $state[$p.Name] = @{ Process = [string]$p.Value.Process; Workspace = [string]$p.Value.Workspace }
    }
    return $state
}

# The state lives in memory and the file is only written, never read back
# while running: a write that fails (the file held by another process) then
# loses nothing, the next one catches up.
function Update-State([hashtable]$State) {
    foreach ($w in Get-ManagedWindows) {
        $State[$w.Handle] = @{ Process = $w.Process; Workspace = $w.Workspace }
    }
    foreach ($handle in @($State.Keys)) {
        if (-not [GlazeWmHelpers.NativeWindows]::IsWindow([IntPtr][int64]$handle)) { $State.Remove($handle) }
    }
}

function Write-StateFile([hashtable]$State) {
    $tmp = "$StateFile.tmp"
    ConvertTo-Json -InputObject $State -Depth 3 | Set-Content -LiteralPath $tmp -Encoding ASCII
    Move-Item -LiteralPath $tmp -Destination $StateFile -Force
}

# Moves each of $Windows that $State knows back to its saved workspace.
function Restore-Workspaces([hashtable]$State, [object[]]$Windows) {
    foreach ($w in $Windows) {
        $saved = $State[$w.Handle]
        if (($null -eq $saved) -or ($saved.Process -ne $w.Process) -or ($saved.Workspace -eq $w.Workspace)) { continue }
        try {
            Invoke-GlazeWM @('command', '--id', $w.Id, 'move', '--workspace', $saved.Workspace) | Out-Null
        } catch { Write-Log $_.Exception.Message }
    }
}

# Uncloaks the lost windows (see the header) and returns their handles once
# GlazeWM manages them; it treats an uncloaked window like a newly shown one.
# A shell-cloaked window that GlazeWM does not manage can only be lost: Store
# apps are left out, and virtual desktops are not used here
# (no-virtual-desktops.ahk).
function Show-LostWindows {
    $cloaked = @([GlazeWmHelpers.NativeWindows]::GetShellCloakedAppWindows() | ForEach-Object { [string]$_.ToInt64() })
    $managed = @(Get-ManagedWindows | ForEach-Object { $_.Handle })
    $lost = @($cloaked | Where-Object { $managed -notcontains $_ })
    foreach ($handle in $lost) {
        try {
            [GlazeWmHelpers.NativeWindows]::Uncloak([IntPtr][int64]$handle)
        } catch { Write-Log ("could not uncloak window {0}: {1}" -f $handle, $_.Exception.Message) }
    }
    if ($lost.Count -gt 0) { Wait-UntilManaged $lost }
    return $lost
}

# Gives up after $ManageTimeoutSeconds, in case GlazeWM ignores a window.
function Wait-UntilManaged([string[]]$Handles) {
    $deadline = (Get-Date).AddSeconds($ManageTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $managed = @(Get-ManagedWindows | ForEach-Object { $_.Handle })
        if (@($Handles | Where-Object { $managed -notcontains $_ }).Count -eq 0) { return }
        Start-Sleep -Milliseconds 250
    }
}

# Each window stays on its workspace; GlazeWM restores it to the state it had
# before (tiling or floating).
function Restore-MinimizedWindows {
    foreach ($w in Get-ManagedWindows) {
        if ($w.State -ne 'minimized') { continue }
        try {
            Invoke-GlazeWM @('command', '--id', $w.Id, 'toggle-minimized') | Out-Null
        } catch { Write-Log $_.Exception.Message }
    }
}

if ($ShowLostWindows) {
    # Read before uncloaking: the running copy of this script records the
    # windows on the current workspace as soon as GlazeWM manages them.
    $saved = @{}
    try { $saved = Read-StateFile } catch { Write-Log $_.Exception.Message }
    try {
        $lost = @(Show-LostWindows)
        Restore-Workspaces $saved @(Get-ManagedWindows | Where-Object { $lost -contains $_.Handle })
        Restore-MinimizedWindows
    } catch { Write-Log $_.Exception.Message }
    exit
}

# GlazeWM manages the windows that are already open as it starts; give it a
# moment so they are all in the tree before they are moved.
Start-Sleep -Seconds 2
$State = @{}
try { $State = Read-StateFile } catch { Write-Log $_.Exception.Message }
try { [void](Show-LostWindows) } catch { Write-Log $_.Exception.Message }
try { Restore-Workspaces $State @(Get-ManagedWindows) } catch { Write-Log $_.Exception.Message }
try { Update-State $State; Write-StateFile $State } catch { Write-Log $_.Exception.Message }

# Each event is one JSON line; which event it was does not matter.
& glazewm sub --events @WatchedEvents | ForEach-Object {
    try { Update-State $State; Write-StateFile $State } catch { Write-Log $_.Exception.Message }
}
Write-Log ("glazewm sub ended (exit code {0})" -f $LASTEXITCODE)
