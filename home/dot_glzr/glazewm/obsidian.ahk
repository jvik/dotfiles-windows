; Obsidian as a scratchpad, toggled with LWin+Shift+O, the physical
; Alt+Shift+O (GlazeWM's mod+Shift+o), since the Scancode Map swaps Left Alt
; and Left Win. Pressing it:
;
; - with Obsidian focused: minimizes it, as sway's scratchpad hid it;
; - with it on another workspace or minimized: moves it to the focused
;   workspace, where it tiles as usual, restores it and focuses it (on the
;   focused workspace but not focused: just focuses it);
; - with no Obsidian window: starts Obsidian, which opens on the focused
;   workspace.
;
; Teams and Slack use summon-app.ps1 for the same idea, but that is slow:
; starting powershell.exe alone takes about 1.7 s here, and each glazewm CLI
; call about 400 ms. This runs in the already running helpers process,
; minimizes without asking GlazeWM, and otherwise sends one query and at most
; one move over GlazeWM's IPC socket (glazewm-ipc.ahk), tens of milliseconds.
; Restoring and focusing are plain Win32 calls that GlazeWM follows.
;
; Included by helpers.ahk; not meant to run on its own.

OBSIDIAN_EXE := EnvGet("LOCALAPPDATA") "\Programs\Obsidian\Obsidian.exe"
OBSIDIAN_PROCESS := "Obsidian"  ; processName in glazewm's replies

<#+o::ToggleObsidian()

ToggleObsidian() {
    if WinActive("ahk_exe " OBSIDIAN_PROCESS ".exe") {
        WinMinimize "A"
        return
    }

    data := GlazeWmRequest("query workspaces")
    if !data
        return
    current := ""
    window := ""
    windowWorkspace := ""
    for workspace in data["workspaces"] {
        if workspace["hasFocus"]
            current := workspace["name"]
        if !window && (window := FindWindowOfProcess(workspace, OBSIDIAN_PROCESS))
            windowWorkspace := workspace["name"]
    }

    if !window {
        Run OBSIDIAN_EXE
        return
    }
    if current && (windowWorkspace != current)
        GlazeWmRequest("command --id " window["id"] " move --workspace " current)
    hwnd := window["handle"]
    if (WinGetMinMax(hwnd) = -1)
        WinRestore hwnd
    WinActivate hwnd
}

; The first window of the process in the container tree under node, or "".
; Windows can sit in nested split containers.
FindWindowOfProcess(node, processName) {
    for child in node["children"] {
        if child.Has("handle") && (child["processName"] = processName)
            return child
        if child.Has("children") && (found := FindWindowOfProcess(child, processName))
            return found
    }
    return ""
}
