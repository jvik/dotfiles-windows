; M365 Copilot Chat as a floating drop-down, toggled with Alt+Space. That is
; the physical Win+Space key, since the Scancode Map swaps Left Alt and Left
; Win. Pressing it:
;
; - with no Copilot window: opens one (and shows it once it has loaded);
; - with the window hidden or behind others: shows it centred on the monitor
;   under the mouse, always on top, and focuses it;
; - with the window focused: hides it again.
;
; The window is M365 Copilot Chat (work account, so work data stays protected)
; in an Edge app window (--app: no tabs or address bar). GlazeWM ignores it
; (window_rules in config.yaml), so it never tiles and, like Bitwarden, shows
; up on whichever workspace you are on. COPILOT_TITLE must match the
; window_title of that rule.
;
; The hotkey takes Alt+Space from the window menu (and from PowerToys Run or
; the Copilot app, if either uses it). Flow Launcher (mod+d) is moved to
; Ctrl+Alt+Space for the same reason.
;
; Included by helpers.ahk; not meant to run on its own.

COPILOT_URL := "https://m365.cloud.microsoft/chat"
; Edge browser windows are titled "<page> - <profile> - Microsoft Edge", an
; app window only "<page>". No "-" in the title therefore rules out browser
; windows, including one with a Copilot tab open.
COPILOT_TITLE := "^[^-]*Copilot[^-]*$"
EDGE_WINDOWS := "ahk_exe msedge.exe ahk_class Chrome_WidgetWin_1"
CHAT_W := 0.5  ; half the monitor's width (see ShowDropDown)
CHAT_H := 900
LAUNCH_TIMEOUT_MS := 20000
SW_SHOWMINNOACTIVE := 7

copilotHwnd := 0  ; found once, so a conversation title change cannot lose it

<!Space::ToggleCopilotChat()

ToggleCopilotChat() {
    DetectHiddenWindows true
    hwnd := FindCopilotChat()
    if !hwnd
        LaunchCopilotChat()
    else if WinActive(hwnd)
        WinHide hwnd
    else
        ShowDropDown(hwnd, CHAT_W, CHAT_H)
}

FindCopilotChat() {
    global copilotHwnd
    if copilotHwnd && WinExist("ahk_id " copilotHwnd " " EDGE_WINDOWS)
        return copilotHwnd
    copilotHwnd := 0
    for hwnd in WinGetList(EDGE_WINDOWS) {
        try {
            if RegExMatch(WinGetTitle(hwnd), COPILOT_TITLE) {
                copilotHwnd := hwnd
                break
            }
        }
    }
    return copilotHwnd
}

; Opens the app window and takes the first new Edge window that is not a
; browser window (Edge may restore its browser windows when it starts). It is
; shown once its title matches COPILOT_TITLE, i.e. once GlazeWM has let go of
; it; on a sign-in page that never happens, so it is shown on the timeout.
LaunchCopilotChat() {
    global copilotHwnd
    existing := Map()
    for hwnd in WinGetList(EDGE_WINDOWS)
        existing[hwnd] := true

    Run "msedge.exe --app=" COPILOT_URL
    deadline := A_TickCount + LAUNCH_TIMEOUT_MS
    while (A_TickCount < deadline) {
        Sleep 250
        if !copilotHwnd {
            for hwnd in WinGetList(EDGE_WINDOWS) {
                if !existing.Has(hwnd) && IsEdgeAppWindow(hwnd) {
                    copilotHwnd := hwnd
                    break
                }
            }
            continue
        }
        try {
            if RegExMatch(WinGetTitle(copilotHwnd), COPILOT_TITLE) {
                ; Give GlazeWM's ignore rule a moment, or it re-tiles the
                ; window after it is placed.
                Sleep 300
                break
            }
        } catch {
            return  ; closed while loading
        }
    }
    if copilotHwnd && WinExist(copilotHwnd)
        ShowDropDown(copilotHwnd, CHAT_W, CHAT_H)
}

IsEdgeAppWindow(hwnd) {
    try {
        if !DllCall("IsWindowVisible", "Ptr", hwnd)
            return false
        title := WinGetTitle(hwnd)
        return title != "" && !RegExMatch(title, "Edge$")
    }
    return false
}

; ShowDropDown makes the window always on top, but that does not last: like
; Bitwarden's, its topmost flag is cleared when you click another window, and it
; sinks behind the tiled windows. Put it back while the window is shown. Uses
; KeepOnTop() from bitwarden-on-top.ahk.
KeepCopilotChatOnTop() {
    global copilotHwnd
    if copilotHwnd && DllCall("IsWindowVisible", "Ptr", copilotHwnd)
        KeepOnTop(copilotHwnd)
}
SetTimer KeepCopilotChatOnTop, 500

; A hidden window has no taskbar button, so leaving it hidden when the helpers
; exit (GlazeWM quits, or a config reload restarts them) would strand it. Hand
; it back minimized instead.
UnhideCopilotChat(*) {
    DetectHiddenWindows true
    hwnd := FindCopilotChat()
    if hwnd && !DllCall("IsWindowVisible", "Ptr", hwnd)
        DllCall("ShowWindow", "Ptr", hwnd, "Int", SW_SHOWMINNOACTIVE)
}
OnExit UnhideCopilotChat
