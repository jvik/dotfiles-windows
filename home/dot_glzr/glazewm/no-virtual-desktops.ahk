; Blocks Windows' shortcuts for creating and switching virtual desktops.
; GlazeWM's workspaces take their place, and Win+Ctrl+D is mod+Ctrl+d here,
; one key away from mod+d (Flow Launcher), so extra desktops were made by
; accident; Win+Ctrl+Left/Right then jumped between them, which looked like a
; workspace switch but showed only that desktop's windows.
;
; Only these exact combinations: mod+Ctrl+Shift+arrows (GlazeWM's
; move-workspace) still work, and so does Win+Ctrl+F4, which closes the
; current desktop and moves its windows to the next one.
;
; Included by helpers.ahk; not meant to run on its own.

#^d::return
#^Left::return
#^Right::return
