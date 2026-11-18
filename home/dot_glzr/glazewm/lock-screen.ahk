; mod+Ctrl+l locks the PC, as it did in sway. mod is lwin, so this is
; Win+Ctrl+L, which Windows 11 uses to toggle Live Captions; that is blocked.
; (mod+l alone also locks: that is Windows' own Win+L.)
;
; Included by helpers.ahk; not meant to run on its own.

#^l::DllCall("LockWorkStation")
