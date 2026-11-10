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
; Included by helpers.ahk; not meant to run on its own.

~LWin::Send "{Blind}{vkE8}"
