; Keeps Bitwarden's windows always on top, the other half of sway's
; floating + sticky. GlazeWM ignores Bitwarden (window_rules in config.yaml) so
; it is never hidden on a workspace switch, but then nothing keeps it above the
; tiled windows of the workspace you switch to.
;
; Started by GlazeWM (startup_commands); exits on its own when GlazeWM is gone.

#Requires AutoHotkey v2.0
#SingleInstance Force

WS_EX_TOPMOST := 0x8

KeepBitwardenOnTop() {
    if !ProcessExist("glazewm.exe")
        ExitApp
    for hwnd in WinGetList("ahk_exe Bitwarden.exe") {
        try {
            if !(WinGetExStyle(hwnd) & WS_EX_TOPMOST)
                WinSetAlwaysOnTop 1, hwnd
        }
    }
}
SetTimer KeepBitwardenOnTop, 500
