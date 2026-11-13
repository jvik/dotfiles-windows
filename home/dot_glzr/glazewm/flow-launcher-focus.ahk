; Lets Flow Launcher close on a click outside it, but not when the pointer
; merely crosses another window.
;
; Flow's "Hide Flow Launcher when focus is lost" (HideWhenDeactivated, set in
; AppData/Roaming/FlowLauncher/Settings/modify_Settings.json) closes it on a
; click outside, but focus follows mouse (run_after_60-focus-follows-mouse)
; also takes focus away on a hover. So while Flow's search window has focus,
; focus follows mouse is paused: only a click (or Esc, or the hotkey) moves
; focus away and closes Flow. It is resumed as soon as anything else gets
; focus.
;
; The pause is not written to the registry, and focus follows mouse is
; resumed when the helpers exit; if they are killed while Flow is open, it is
; back after the next sign-in.
;
; Included by helpers.ahk; not meant to run on its own.

; Flow's search window; its settings and other windows have other titles.
FLOW_WINDOW := "Flow.Launcher ahk_exe Flow.Launcher.exe"
EVENT_SYSTEM_FOREGROUND := 0x0003
WINEVENT_OUTOFCONTEXT := 0x0000
SPI_GETACTIVEWINDOWTRACKING := 0x1000
SPI_SETACTIVEWINDOWTRACKING := 0x1001

hoverFocusPaused := false

IsHoverFocusOn() {
    enabled := 0
    DllCall("SystemParametersInfo", "UInt", SPI_GETACTIVEWINDOWTRACKING, "UInt", 0, "Int*", &enabled, "UInt", 0)
    return enabled != 0
}

; fWinIni 0: neither persisted nor broadcast, so the registry keeps the
; setting from run_after_60-focus-follows-mouse.
SetHoverFocus(on) {
    DllCall("SystemParametersInfo", "UInt", SPI_SETACTIVEWINDOWTRACKING, "UInt", 0, "Ptr", on, "UInt", 0)
}

ResumeHoverFocus(*) {
    global hoverFocusPaused
    if hoverFocusPaused {
        SetHoverFocus(true)
        hoverFocusPaused := false
    }
}

OnForegroundChange(hook, event, hwnd, *) {
    global hoverFocusPaused
    isFlow := false
    try isFlow := WinExist(FLOW_WINDOW " ahk_id " hwnd) != 0
    if isFlow {
        if !hoverFocusPaused && IsHoverFocusOn() {
            SetHoverFocus(false)
            hoverFocusPaused := true
        }
    } else {
        ResumeHoverFocus()
    }
}

; An event hook rather than a timer: Flow must have hover focus off before
; the pointer moves, i.e. right when it opens.
DllCall("SetWinEventHook"
    , "UInt", EVENT_SYSTEM_FOREGROUND, "UInt", EVENT_SYSTEM_FOREGROUND
    , "Ptr", 0, "Ptr", CallbackCreate(OnForegroundChange, "F", 7)
    , "UInt", 0, "UInt", 0, "UInt", WINEVENT_OUTOFCONTEXT, "Ptr")
OnExit ResumeHoverFocus
