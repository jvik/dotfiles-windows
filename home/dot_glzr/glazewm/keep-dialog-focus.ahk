; Pauses focus follows mouse while a dialog or Flow Launcher has focus, so
; the pointer merely crossing another window does not take focus from them.
;
; Flow's "Hide Flow Launcher when focus is lost" (HideWhenDeactivated, set in
; AppData/Roaming/FlowLauncher/Settings/modify_Settings.json) closes it on a
; click outside, but focus follows mouse (run_after_60-focus-follows-mouse)
; also takes focus away on a hover. So while Flow's search window has focus,
; focus follows mouse is paused: only a click (or Esc, or the hotkey) moves
; focus away and closes Flow. It is resumed as soon as anything else gets
; focus.
;
; Dialogs get the same pause. They often open away from the pointer, so the
; first mouse move gave focus to the tiled window under the pointer and the
; dialog was lost behind it. A dialog is (see IsDialog):
; - a standard Win32 dialog (class #32770): message boxes, Open/Save,
;   Properties, Find, Run, most Control Panel dialogs;
; - any modal dialog, whatever its toolkit: its owner window is disabled
;   while it is open;
; - Windows' Open With dialog ("Open with" > "Choose another app"), which is
;   neither (an unowned tool window that GlazeWM leaves alone).
;
; The pause is not written to the registry, and focus follows mouse is
; resumed when the helpers exit; if they are killed during a pause, it is
; back after the next sign-in.
;
; Included by helpers.ahk; not meant to run on its own.

; Flow's search window; its settings and other windows have other titles.
FLOW_WINDOW := "Flow.Launcher ahk_exe Flow.Launcher.exe"
; Untitled; the class name is the same in every UI language.
OPEN_WITH_WINDOW := "ahk_exe OpenWith.exe ahk_class Open With"
STANDARD_DIALOG_CLASS := "#32770"
GW_OWNER := 4
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

; Windows disables a modal dialog's owner until the dialog closes.
IsModalDialog(hwnd) {
    owner := DllCall("GetWindow", "Ptr", hwnd, "UInt", GW_OWNER, "Ptr")
    return owner && !DllCall("IsWindowEnabled", "Ptr", owner)
}

IsDialog(hwnd) {
    return WinGetClass(hwnd) = STANDARD_DIALOG_CLASS
        || IsModalDialog(hwnd)
        || WinExist(OPEN_WITH_WINDOW " ahk_id " hwnd)
}

OnForegroundChange(hook, event, hwnd, *) {
    global hoverFocusPaused
    ; Some windows get focus before they are shown (Open With does), and
    ; AutoHotkey skips hidden windows by default. Applies to this call only.
    DetectHiddenWindows true
    needsPause := false
    try needsPause := WinExist(FLOW_WINDOW " ahk_id " hwnd) || IsDialog(hwnd)
    if needsPause {
        if !hoverFocusPaused && IsHoverFocusOn() {
            SetHoverFocus(false)
            hoverFocusPaused := true
        }
    } else {
        ResumeHoverFocus()
    }
}

; An event hook rather than a timer: hover focus must be off before the
; pointer moves, i.e. right when the window opens.
DllCall("SetWinEventHook"
    , "UInt", EVENT_SYSTEM_FOREGROUND, "UInt", EVENT_SYSTEM_FOREGROUND
    , "Ptr", 0, "Ptr", CallbackCreate(OnForegroundChange, "F", 7)
    , "UInt", 0, "UInt", 0, "UInt", WINEVENT_OUTOFCONTEXT, "Ptr")
OnExit ResumeHoverFocus
