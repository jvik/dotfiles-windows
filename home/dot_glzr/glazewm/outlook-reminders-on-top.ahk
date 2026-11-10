; Keeps new Outlook's reminders window always on top, the other half of
; floating + sticky. GlazeWM ignores it (window_rules in config.yaml) so it is
; never hidden on a workspace switch, but then nothing keeps it above the tiled
; windows of the workspace you switch to.
;
; REMINDERS_TITLE must match the window_title rule in config.yaml. Written with
; escapes to keep this file ASCII: \x{E5} is "a with ring", \x{2013} is the en
; dash Outlook puts between the parts of its titles.
;
; Uses KeepOnTop() from bitwarden-on-top.ahk.
;
; Included by helpers.ahk; not meant to run on its own.

; e.g. "Paaminnelser - Vik, Jorgen - Outlook", in Norwegian or English
REMINDERS_TITLE := "^(P\x{E5}minnelser|Reminders) \x{2013} "

KeepOutlookRemindersOnTop() {
    for hwnd in WinGetList("ahk_exe olk.exe ahk_class Outlook Host") {
        try {
            if RegExMatch(WinGetTitle(hwnd), REMINDERS_TITLE)
                KeepOnTop(hwnd)
        }
    }
}
SetTimer KeepOutlookRemindersOnTop, 500
