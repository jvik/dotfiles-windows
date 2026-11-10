; Signal Desktop as a floating drop-down, toggled with LWin+Shift+N. That is
; the physical Alt+Shift+N (GlazeWM's mod+Shift+N), since the Scancode Map
; swaps Left Alt and Left Win. Pressing it:
;
; - with the window hidden in the tray, or Signal not running: starts
;   Signal.exe, which shows the window, then places it as below;
; - with the window behind others: shows it centred on the monitor under the
;   mouse, always on top, and focuses it;
; - with the window focused: closes it to the tray.
;
; Unlike Copilot Chat, Signal is never hidden or shown with WinHide/WinShow:
; Electron does not notice a window shown behind its back and the window then
; ignores mouse and keyboard. Closing it is the same as clicking X, and a
; second Signal.exe makes the running one show its window itself. This needs
; Signal's "Minimize to system tray" setting; without it, closing quits Signal
; and the next press starts it again.
;
; GlazeWM ignores Signal's windows (window_rules in config.yaml), so it never
; tiles and shows up on whichever workspace you are on, like Copilot Chat
; (copilot-chat.ahk).
;
; Included by helpers.ahk; not meant to run on its own.

SIGNAL_EXE := EnvGet("LOCALAPPDATA") "\Programs\signal-desktop\Signal.exe"
; Electron also has hidden helper windows (Chrome_WidgetWin_0, no title).
SIGNAL_WINDOWS := "ahk_exe Signal.exe ahk_class Chrome_WidgetWin_1"
SIGNAL_TITLE := "^Signal"
SIGNAL_W := 1100  ; at 100% scaling
SIGNAL_H := 850
SIGNAL_LAUNCH_TIMEOUT_MS := 20000

<#+n::ToggleSignal()

ToggleSignal() {
    DetectHiddenWindows true
    hwnd := FindSignal()
    if !hwnd || !DllCall("IsWindowVisible", "Ptr", hwnd)
        ShowSignalFromTray()
    else if WinActive(hwnd)
        WinClose hwnd
    else
        ShowDropDown(hwnd, SIGNAL_W, SIGNAL_H)
}

FindSignal() {
    for hwnd in WinGetList(SIGNAL_WINDOWS) {
        try {
            if RegExMatch(WinGetTitle(hwnd), SIGNAL_TITLE)
                return hwnd
        }
    }
    return 0
}

; Starting Signal.exe either starts Signal or, if it is already running, makes
; it show its window. Signal shows the window itself (when a fresh start has
; loaded the page), so it is only placed once it is visible; if it never
; becomes visible it is left alone rather than shown behind Electron's back.
ShowSignalFromTray() {
    Run SIGNAL_EXE
    deadline := A_TickCount + SIGNAL_LAUNCH_TIMEOUT_MS
    while (A_TickCount < deadline) {
        Sleep 250
        hwnd := FindSignal()
        if hwnd && DllCall("IsWindowVisible", "Ptr", hwnd) {
            ShowDropDown(hwnd, SIGNAL_W, SIGNAL_H)
            return
        }
    }
}
