; Shared by the floating drop-downs (copilot-chat.ahk, signal.ahk): shows a
; window centred on the monitor under the mouse, always on top, and focused.
; The window must be ignored by GlazeWM (window_rules in config.yaml), or it
; tiles it again.
;
; Included by helpers.ahk; not meant to run on its own.

; width and height are pixels at 100% scaling, or, if at most 1, a fraction of
; the monitor's work area.
ShowDropDown(hwnd, width, height) {
    monitor := MonitorUnderMouse()
    if (WinGetMinMax(hwnd) != 0)  ; minimized or maximized
        WinRestore hwnd
    CenterOnMonitor(hwnd, monitor, width, height)
    WinShow hwnd
    WinSetAlwaysOnTop 1, hwnd
    WinActivate hwnd
}

; Focus follows the mouse, so this is the monitor you are working on.
MonitorUnderMouse() {
    CoordMode "Mouse", "Screen"
    MouseGetPos &x, &y
    loop MonitorGetCount() {
        MonitorGet A_Index, &l, &t, &r, &b
        if (x >= l && x < r && y >= t && y < b)
            return A_Index
    }
    return MonitorGetPrimary()
}

CenterOnMonitor(hwnd, monitor, width, height) {
    scale := DllCall("GetDpiForWindow", "Ptr", hwnd, "UInt") / 96
    MonitorGetWorkArea monitor, &l, &t, &r, &b
    w := Min(Round(width <= 1 ? width * (r - l) : width * scale), r - l)
    h := Min(Round(height <= 1 ? height * (b - t) : height * scale), b - t)
    WinMove l + (r - l - w) // 2, t + (b - t - h) // 2, w, h, hwnd
}
