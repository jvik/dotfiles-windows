; New WezTerm window, opened by the WezTerm process that is already running
; instead of starting another wezterm-gui.exe (which takes 1-1.5 s before the
; window shows: GPU, fonts, config). Bound to Win+Enter in PowerToys
; (.chezmoidata/powertoys.yaml). Falls back to starting wezterm-gui.exe when
; none is running, or when the running one cannot be reached.
;
; AutoHotkey rather than PowerShell: it starts in a few ms and has no console
; window. `wezterm cli` is given the full socket path because wezterm
; 20240203 hands it a relative one (gui-sock-<pid>) that it cannot connect to.

#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off

weztermDir := "C:\Program Files\WezTerm"
sockDir := EnvGet("USERPROFILE") "\.local\share\wezterm"
winSpec := "ahk_exe wezterm-gui.exe"

before := WinGetList(winSpec)

tried := Map()
for hwnd in before {
    pid := WinGetPID(hwnd)
    if tried.Has(pid)
        continue
    tried[pid] := true
    sock := sockDir "\gui-sock-" pid
    if !FileExist(sock)
        continue
    EnvSet("WEZTERM_UNIX_SOCKET", sock)
    if RunWait('"' weztermDir '\wezterm.exe" cli --no-auto-start spawn --new-window', , "Hide") = 0 {
        FocusNewWindow(before)
        ExitApp
    }
}

Run('"' weztermDir '\wezterm-gui.exe"')
ExitApp

; The window is created by the running process, which does not own the
; foreground, so it may open behind the current one: bring it forward.
FocusNewWindow(before) {
    deadline := A_TickCount + 3000
    while A_TickCount < deadline {
        for hwnd in WinGetList(winSpec) {
            isNew := true
            for old in before {
                if old = hwnd {
                    isNew := false
                    break
                }
            }
            if isNew {
                WinActivate(hwnd)
                return
            }
        }
        Sleep 20
    }
}
