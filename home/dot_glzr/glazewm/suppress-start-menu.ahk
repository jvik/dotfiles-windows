; Keeps the mod key (lwin, the physical Left Alt) from opening the Start menu
; when it is tapped alone. GlazeWM (since v3.2) only suppresses it after its
; own keybindings.
;
; Windows opens Start when Win is released with no other key in between, so
; every Win press also sends vkE8, a virtual-key code Windows leaves
; unassigned. "~" passes Win through untouched and {Blind} keeps it held, so
; GlazeWM and the PowerToys shortcuts still see Win as a modifier.
; Ctrl+Esc still opens Start.
;
; Started by GlazeWM (startup_commands); exits on its own when GlazeWM is gone.

#Requires AutoHotkey v2.0
#SingleInstance Force

~LWin::Send "{Blind}{vkE8}"

ExitWhenGlazeWmIsGone() {
    if !ProcessExist("glazewm.exe")
        ExitApp
}
SetTimer ExitWhenGlazeWmIsGone, 5000
