; Keeps Greenshot's dialogs ("Save image?" when closing the editor, Save As)
; always on top. They are owned by the editor window, and GlazeWM leaves owned
; windows alone, so a window_rule never applies to them and they can sink
; behind the tiled windows.
;
; Uses KeepOnTop() from bitwarden-on-top.ahk.
;
; Included by helpers.ahk; not meant to run on its own.

KeepGreenshotDialogsOnTop() {
    for hwnd in WinGetList("ahk_exe Greenshot.exe ahk_class #32770")
        KeepOnTop(hwnd)
}
SetTimer KeepGreenshotDialogsOnTop, 500
