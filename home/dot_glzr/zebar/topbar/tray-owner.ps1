# Prints "<hwnd>=<process name>" for each window handle given, so the Zebar
# bar can tell tray icons apart when the app leaves the tooltip empty (Signal,
# Bitwarden). Unknown handles print an empty name.
param([Parameter(ValueFromRemainingArguments)][long[]]$Handles)

Add-Type -Namespace TrayOwner -Name Native -MemberDefinition @'
[DllImport("user32.dll")]
public static extern uint GetWindowThreadProcessId(System.IntPtr hWnd, out uint processId);
'@

foreach ($handle in $Handles) {
    $processId = 0
    $name = ''
    if ([TrayOwner.Native]::GetWindowThreadProcessId([IntPtr]$handle, [ref]$processId) -ne 0) {
        $name = (Get-Process -Id $processId -ErrorAction SilentlyContinue).ProcessName
    }
    "$handle=$name"
}
