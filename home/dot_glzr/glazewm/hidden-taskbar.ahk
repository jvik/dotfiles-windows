; Hides the Windows taskbar completely; Zebar's bar takes its place. mod+t
; (the physical Alt+T) shows it as a normal taskbar, and mod+t again hides it.
;
; Hidden, the taskbar is set to auto-hide so it gives its screen space back,
; and its windows are hidden so it does not slide in at the screen edge
; either. Explorer shows them again now and then (Start menu, Explorer
; restart), so a timer hides them again. On exit the auto-hide setting is
; restored and the taskbar shown, so it never stays lost when the helpers stop.
;
; Included by helpers.ahk; not meant to run on its own.

TASKBAR_CLASSES := ["Shell_TrayWnd", "Shell_SecondaryTrayWnd"]

ABM_GETSTATE := 0x4
ABM_SETSTATE := 0xA
ABS_AUTOHIDE := 0x1
APPBARDATA_SIZE := A_PtrSize = 8 ? 48 : 36
APPBARDATA_LPARAM_OFFSET := A_PtrSize = 8 ? 40 : 32

taskbarShown := false

; ---- Auto-hide setting ----

AppBarState(message, state := 0) {
    data := Buffer(APPBARDATA_SIZE, 0)
    NumPut "UInt", APPBARDATA_SIZE, data, 0
    DetectHiddenWindows true
    NumPut "Ptr", WinExist("ahk_class Shell_TrayWnd ahk_exe explorer.exe"), data, A_PtrSize
    DetectHiddenWindows false
    NumPut "Ptr", state, data, APPBARDATA_LPARAM_OFFSET
    return DllCall("Shell32\SHAppBarMessage", "UInt", message, "Ptr", data, "UPtr")
}

originalAppBarState := AppBarState(ABM_GETSTATE)

SetAutoHide(enabled) {
    state := enabled ? originalAppBarState | ABS_AUTOHIDE : originalAppBarState & ~ABS_AUTOHIDE
    AppBarState ABM_SETSTATE, state
}

RestoreTaskbar(*) {
    AppBarState ABM_SETSTATE, originalAppBarState
    SetTaskbarVisible true
}
OnExit RestoreTaskbar

; ---- Showing and hiding ----

; Explorer's only: Zebar's systray provider has a hidden window of the same
; class to receive the tray icons, and showing it opens a blank window.
TaskbarWindows() {
    windows := []
    DetectHiddenWindows true
    for className in TASKBAR_CLASSES
        for hwnd in WinGetList("ahk_class " className " ahk_exe explorer.exe")
            windows.Push(hwnd)
    DetectHiddenWindows false
    return windows
}

SetTaskbarVisible(visible) {
    for hwnd in TaskbarWindows() {
        try {
            if visible
                WinShow hwnd
            else if DllCall("IsWindowVisible", "Ptr", hwnd)
                WinHide hwnd
        }
    }
}

ToggleTaskbar() {
    global taskbarShown
    taskbarShown := !taskbarShown
    SetAutoHide !taskbarShown
    SetTaskbarVisible taskbarShown
}

KeepTaskbarHidden() {
    if !taskbarShown
        SetTaskbarVisible false
}

SetAutoHide true
KeepTaskbarHidden()
SetTimer KeepTaskbarHidden, 250

#t::ToggleTaskbar()
