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
; up on whichever workspace you are on. The window is titled after the
; conversation, so the rule ignores every Edge app window rather than
; matching "Copilot": GlazeWM checks it again on every WinShow, and a
; conversation name would make it tile.
;
; The hotkey takes Alt+Space from the window menu (and from PowerToys Run or
; the Copilot app, if either uses it). Flow Launcher (mod+d) is moved to
; Ctrl+Alt+Space for the same reason.
;
; Included by helpers.ahk; not meant to run on its own.

COPILOT_URL := "https://m365.cloud.microsoft/chat"
; Edge browser windows are titled "<page> - <profile> - Microsoft Edge", an
; app window only "<page>". Keep in sync with the window rule in config.yaml.
EDGE_BROWSER_TITLE := "Microsoft Edge$"
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

; Once the helpers restart, the window is found again by its title: an Edge
; app window, preferably one with "Copilot" in the title (a new chat), else
; any (a named conversation).
FindCopilotChat() {
    global copilotHwnd
    if copilotHwnd && WinExist("ahk_id " copilotHwnd " " EDGE_WINDOWS)
        return copilotHwnd
    copilotHwnd := 0
    anyAppWindow := 0
    for hwnd in WinGetList(EDGE_WINDOWS) {
        try title := WinGetTitle(hwnd)
        catch
            continue
        if !IsEdgeAppTitle(title)
            continue
        if InStr(title, "Copilot")
            return copilotHwnd := hwnd
        if !anyAppWindow
            anyAppWindow := hwnd
    }
    return copilotHwnd := anyAppWindow
}

; Opens the app window and takes the first new visible Edge window that is
; not a browser window (Edge may restore its browser windows when it starts).
; GlazeWM ignores it from the start, sign-in page included.
LaunchCopilotChat() {
    global copilotHwnd
    existing := Map()
    for hwnd in WinGetList(EDGE_WINDOWS)
        existing[hwnd] := true

    Run "msedge.exe --app=" COPILOT_URL
    deadline := A_TickCount + LAUNCH_TIMEOUT_MS
    while !copilotHwnd && (A_TickCount < deadline) {
        Sleep 250
        for hwnd in WinGetList(EDGE_WINDOWS) {
            if !existing.Has(hwnd) && IsEdgeAppWindow(hwnd) {
                copilotHwnd := hwnd
                break
            }
        }
    }
    ; Give GlazeWM's ignore rule a moment, or it re-tiles the window after it
    ; is placed.
    Sleep 300
    if copilotHwnd && WinExist(copilotHwnd)
        ShowDropDown(copilotHwnd, CHAT_W, CHAT_H)
}

IsEdgeAppWindow(hwnd) {
    try return DllCall("IsWindowVisible", "Ptr", hwnd) && IsEdgeAppTitle(WinGetTitle(hwnd))
    return false
}

IsEdgeAppTitle(title) {
    return title != "" && !RegExMatch(title, EDGE_BROWSER_TITLE)
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
