; GlazeWM's AutoHotkey helpers, as one process with one tray icon. Each helper
; is its own file, included below; a new helper is one more #Include line.
; Helpers only define hotkeys, functions and timers: the directives and the
; exit check live here.
;
; Started by GlazeWM (startup_commands, and config_reload_commands so edits
; apply on a reload); exits on its own when GlazeWM is gone.

#Requires AutoHotkey v2.0
#SingleInstance Force

A_IconTip := "GlazeWM helpers"

#Include %A_ScriptDir%\suppress-start-menu.ahk
#Include %A_ScriptDir%\bitwarden-on-top.ahk
#Include %A_ScriptDir%\greenshot-dialogs-on-top.ahk

ExitWhenGlazeWmIsGone() {
    if !ProcessExist("glazewm.exe")
        ExitApp
}
SetTimer ExitWhenGlazeWmIsGone, 5000
