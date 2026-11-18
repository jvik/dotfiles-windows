; Windows Terminal's quake window on Win + the key above Tab ("|" on a
; Norwegian keyboard, scancode 41; mod is lwin, so the physical Alt+|), on the
; monitor under the mouse. Windows Terminal binds the key itself (the
; User.quakeToMouse action in its settings.json, managed by this repo:
; globalSummon "_quake" with "monitor": "toMouse"), but needs help twice:
;
; - It only listens while WindowsTerminal.exe runs, so with it closed this
;   starts it with the quake window.
; - Its move to another monitor keeps the window's size and offset, and then
;   sizes it for whichever monitor holds most of it. The window is as wide as
;   the 3840 px main monitor, so moved onto the 1920 px laptop screen to its
;   left it still overlaps the main one by 7 px more, and lands there again;
;   the next press then cannot hide it either. So this moves the window to the
;   mouse's monitor itself: a hidden one only gets its restored position moved
;   before Windows Terminal shows it, a visible one is moved and focused.
;
; Assumes the only Windows Terminal window is the quake window (WezTerm is the
; terminal for everything else; GlazeWM ignores Windows Terminal, see
; config.yaml). "$" uses the keyboard hook, so the hotkey neither takes the
; key from Windows Terminal's RegisterHotKey nor sees its own Send.
;
; Included by helpers.ahk; not meant to run on its own.

WT_WINDOW := "ahk_exe WindowsTerminal.exe ahk_class CASCADIA_HOSTING_WINDOW_CLASS"
WT_LAUNCH_TIMEOUT_MS := 5000

$#SC029::SummonQuake()

SummonQuake() {
    DetectHiddenWindows true
    hwnd := WinExist(WT_WINDOW)
    mouseMonitor := MonitorUnderMouse()  ; MonitorUnderMouse, MonitorAt: dropdown.ahk
    if !hwnd {
        Run "wt.exe -w _quake"
        deadline := A_TickCount + WT_LAUNCH_TIMEOUT_MS
        while !((hwnd := WinExist(WT_WINDOW)) && DllCall("IsWindowVisible", "Ptr", hwnd)) {
            if (A_TickCount > deadline)
                return
            Sleep 50
        }
        MoveQuakeIfElsewhere(hwnd, mouseMonitor)
    } else if !DllCall("IsWindowVisible", "Ptr", hwnd) {
        rect := GetRestoredRect(hwnd)
        from := MonitorAt(rect.x + rect.w // 2, rect.y + rect.h // 2)
        if (from != mouseMonitor)
            SetRestoredRect(hwnd, QuakeRectOn(rect, from, mouseMonitor))
        Send "{Blind}{SC029}"  ; Win is still held: Windows Terminal shows it
    } else if !MoveQuakeIfElsewhere(hwnd, mouseMonitor)
        Send "{Blind}{SC029}"  ; on this monitor: Windows Terminal toggles it
}

; Moves a visible quake window to the monitor and focuses it, unless it is
; already there. True if it was moved.
MoveQuakeIfElsewhere(hwnd, monitor) {
    WinGetPos &x, &y, &w, &h, hwnd
    from := MonitorAt(x + w // 2, y + h // 2)
    if (from = monitor)
        return false
    rect := QuakeRectOn({x: x, y: y, w: w, h: h}, from, monitor)
    WinMove rect.x, rect.y, rect.w, rect.h, hwnd
    WinActivate hwnd
    return true
}

; Windows Terminal makes the quake window as wide as the monitor's work area
; and half as high, plus its invisible borders. Keeps those offsets and
; extras on the new monitor.
QuakeRectOn(rect, fromMonitor, toMonitor) {
    MonitorGetWorkArea fromMonitor, &fl, &ft, &fr, &fb
    MonitorGetWorkArea toMonitor, &tl, &tt, &tr, &tb
    return {x: tl + rect.x - fl, y: tt + rect.y - ft,
        w: (tr - tl) + rect.w - (fr - fl),
        h: (tb - tt) // 2 + rect.h - (fb - ft) // 2}
}

; The restored position of a hidden (minimized) window, in screen coordinates.
; WINDOWPLACEMENT stores it in workspace coordinates, which start at the
; primary monitor's work area.
GetRestoredRect(hwnd) {
    placement := WindowPlacement(hwnd)
    MonitorGetWorkArea MonitorGetPrimary(), &ox, &oy
    l := NumGet(placement, 28, "Int"), t := NumGet(placement, 32, "Int")
    return {x: l + ox, y: t + oy, w: NumGet(placement, 36, "Int") - l, h: NumGet(placement, 40, "Int") - t}
}

SetRestoredRect(hwnd, rect) {
    static SW_HIDE := 0  ; keep it hidden; Windows Terminal shows it
    placement := WindowPlacement(hwnd)
    MonitorGetWorkArea MonitorGetPrimary(), &ox, &oy
    NumPut("UInt", SW_HIDE, placement, 8)
    NumPut("Int", rect.x - ox, "Int", rect.y - oy, "Int", rect.x - ox + rect.w, "Int", rect.y - oy + rect.h, placement, 28)
    DllCall("SetWindowPlacement", "Ptr", hwnd, "Ptr", placement)
}

WindowPlacement(hwnd) {
    placement := Buffer(44, 0)
    NumPut("UInt", placement.Size, placement)
    DllCall("GetWindowPlacement", "Ptr", hwnd, "Ptr", placement)
    return placement
}
