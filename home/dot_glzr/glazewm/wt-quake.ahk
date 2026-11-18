; Makes Windows Terminal's quake window (Win + the key above Tab, "|" on a
; Norwegian keyboard: scancode 41, wt's default "win+sc(41)") work even when
; Windows Terminal is not running. mod is lwin, so this is the physical
; Alt+|.
;
; Windows Terminal registers that hotkey itself, but only while
; WindowsTerminal.exe runs: after its last window is closed nothing listens
; and the key does nothing. So while it is not running, this hotkey starts it
; with the quake window open. While it runs, the hotkey is off and the key
; passes through to Windows Terminal, which toggles the window as usual. The
; hidden quake window then keeps the process alive. GlazeWM ignores Windows
; Terminal (window_rules in config.yaml), so the window is not tiled.
;
; "$" makes the hotkey use the keyboard hook rather than RegisterHotKey, so it
; never takes the hotkey from Windows Terminal (only one program can register
; it).
;
; Included by helpers.ahk; not meant to run on its own.

#HotIf !ProcessExist("WindowsTerminal.exe")
$#SC029::Run "wt.exe -w _quake"
#HotIf
