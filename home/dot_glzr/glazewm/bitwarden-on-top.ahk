; Keeps Bitwarden's windows always on top, the other half of sway's
; floating + sticky. GlazeWM ignores Bitwarden (window_rules in config.yaml) so
; it is never hidden on a workspace switch, but then nothing keeps it above the
; tiled windows of the workspace you switch to.
;
; Covers Bitwarden Desktop and the Firefox extension's pop-out window (the
; "pop out" button in the extension popup). The toolbar dropdown itself is a
; Firefox panel that closes when it loses focus, so it cannot be made sticky.
; FIREFOX_POPOUT_TITLE must match the window_title rule in config.yaml.
;
; GlazeWM does not place ignored windows, so this script also gives each new
; pop-out POPOUT_W x POPOUT_H (at 100% scaling), centred on its monitor. Once
; only: moving or resizing it afterwards sticks.
;
; Included by helpers.ahk; not meant to run on its own.

WS_EX_TOPMOST := 0x8
; e.g. "Extension: (Bitwarden Password Manager) - Bitwarden — Mozilla Firefox"
FIREFOX_POPOUT_TITLE := "^Extension: \(Bitwarden Password Manager\)"
POPOUT_W := 450
POPOUT_H := 700

placed := Map()  ; pop-out hwnds already sized and centred

KeepOnTop(hwnd) {
    try {
        if !(WinGetExStyle(hwnd) & WS_EX_TOPMOST)
            WinSetAlwaysOnTop 1, hwnd
    }
}

; Monitor whose area contains the window's centre, else the primary one.
MonitorOf(hwnd) {
    WinGetPos &x, &y, &w, &h, hwnd
    cx := x + w // 2, cy := y + h // 2
    loop MonitorGetCount() {
        MonitorGet A_Index, &l, &t, &r, &b
        if (cx >= l && cx < r && cy >= t && cy < b)
            return A_Index
    }
    return MonitorGetPrimary()
}

CenterPopout(hwnd) {
    scale := DllCall("GetDpiForWindow", "Ptr", hwnd, "UInt") / 96
    MonitorGetWorkArea MonitorOf(hwnd), &l, &t, &r, &b
    w := Min(Round(POPOUT_W * scale), r - l)
    h := Min(Round(POPOUT_H * scale), b - t)
    WinMove l + (r - l - w) // 2, t + (b - t - h) // 2, w, h, hwnd
}

KeepBitwardenOnTop() {
    global placed
    for hwnd in WinGetList("ahk_exe Bitwarden.exe")
        KeepOnTop(hwnd)

    seen := Map()
    for hwnd in WinGetList("ahk_exe firefox.exe ahk_class MozillaDialogClass") {
        try {
            if !RegExMatch(WinGetTitle(hwnd), FIREFOX_POPOUT_TITLE)
                continue
            seen[hwnd] := true
            if !placed.Has(hwnd) {
                CenterPopout(hwnd)
                placed[hwnd] := true
            }
            KeepOnTop(hwnd)
        }
    }
    ; Forget closed pop-outs so a reused hwnd gets centred again.
    for hwnd in [placed*]
        if !seen.Has(hwnd)
            placed.Delete(hwnd)
}
SetTimer KeepBitwardenOnTop, 500
