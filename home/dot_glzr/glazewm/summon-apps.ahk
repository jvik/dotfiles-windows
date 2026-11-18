; Teams, Slack and Obsidian as scratchpads, a stand-in for sway's, which
; GlazeWM lacks. LWin is mod (the physical Left Alt). Pressing the hotkey:
;
; - app on another workspace, or minimized: moves it to the focused workspace
;   (where it tiles), restores it and focuses it;
; - app already on the focused workspace: Teams and Slack go back to their
;   home workspace (just focused when you are on it); Obsidian is minimized
;   when focused, as sway's scratchpad hid it, else focused;
; - no window (not running, or closed to the tray): starts the app and fetches
;   its window once GlazeWM manages it.
;
; At most one query and one move over glazewm-ipc.ahk (a few ms); restore and
; focus are Win32 calls that GlazeWM follows. The PowerShell version took ~3 s.
;
; Included by helpers.ahk; not meant to run on its own.

; Keep in sync with the window rule that opens Teams and Slack there
; (config.yaml).
TEAMS_SLACK_HOME := "4"
SUMMON_LAUNCH_TIMEOUT_MS := 15000

; New Teams is ms-teams, classic Teams is Teams (GlazeWM's processName).
<#+t::SummonApp(["ms-teams", "Teams"], "msteams:", TEAMS_SLACK_HOME)
<#+s::SummonApp(["Slack"], "slack://open", TEAMS_SLACK_HOME)
<#+o::SummonApp(["Obsidian"], EnvGet("LOCALAPPDATA") "\Programs\Obsidian\Obsidian.exe")

; Without homeWorkspace, the press that would send the app home minimizes it.
SummonApp(processNames, launch, homeWorkspace := "") {
    if !homeWorkspace && IsActiveProcess(processNames) {
        WinMinimize "A"  ; no need to ask GlazeWM
        return
    }
    app := FindApp(processNames)
    if !app
        return
    if !app.window {
        Run launch
        FetchWhenManaged(processNames, A_TickCount + SUMMON_LAUNCH_TIMEOUT_MS)
        return
    }
    minimized := (WinGetMinMax(app.window["handle"]) = -1)
    if homeWorkspace && (app.workspace = app.current) && !minimized && (app.current != homeWorkspace)
        GlazeWmRequest("command --id " app.window["id"] " move --workspace " homeWorkspace)
    else
        Fetch(app)
}

; Polls on a timer, so other hotkeys keep working while the app starts.
FetchWhenManaged(processNames, deadline) {
    app := FindApp(processNames)
    if app && app.window
        Fetch(app)
    else if (A_TickCount < deadline)
        SetTimer () => FetchWhenManaged(processNames, deadline), -250
}

Fetch(app) {
    if app.current && (app.workspace != app.current)
        GlazeWmRequest("command --id " app.window["id"] " move --workspace " app.current)
    hwnd := app.window["handle"]
    if (WinGetMinMax(hwnd) = -1)
        WinRestore hwnd  ; GlazeWM puts it back as tiling or floating, as before
    WinActivate hwnd
}

; {window, workspace, current}: the app's first managed window ("" if none)
; and its workspace, and the focused workspace. false if GlazeWM is unreachable.
FindApp(processNames) {
    data := GlazeWmRequest("query workspaces")
    if !data
        return false
    app := {window: "", workspace: "", current: ""}
    for workspace in data["workspaces"] {
        if workspace["hasFocus"]
            app.current := workspace["name"]
        if !app.window && (app.window := FindWindowOfProcess(workspace, processNames))
            app.workspace := workspace["name"]
    }
    return app
}

; The first window of one of the processes in the container tree under node,
; or "". Windows can sit in nested split containers.
FindWindowOfProcess(node, processNames) {
    for child in node["children"] {
        if child.Has("handle") && IsOneOf(child["processName"], processNames)
            return child
        if child.Has("children") && (found := FindWindowOfProcess(child, processNames))
            return found
    }
    return ""
}

IsActiveProcess(processNames) {
    try return IsOneOf(RegExReplace(WinGetProcessName("A"), "i)\.exe$"), processNames)
    return false
}

IsOneOf(value, list) {
    for item in list {
        if (value = item)  ; case-insensitive
            return true
    }
    return false
}
