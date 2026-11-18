; Shared by helpers that talk to GlazeWM (summon-apps.ahk): sends messages to
; GlazeWM's IPC WebSocket and parses the JSON replies. Messages are the glazewm
; CLI's arguments as one string, e.g. "query workspaces".
;
; The CLI takes about 400 ms per call (a new process and connection); over one
; connection kept open, a message takes a few ms. WinHTTP's WebSocket API needs
; nothing installed. "127.0.0.1", not "localhost": that tries IPv6 first and
; takes seconds to fall back.
;
; Included by helpers.ahk; not meant to run on its own.

GLAZEWM_IPC_HOST := "127.0.0.1"
GLAZEWM_IPC_PORT := 6123
GLAZEWM_IPC_TIMEOUT_MS := 2000

; Connect now rather than on the first hotkey press: connecting takes ~400 ms.
SetTimer () => GlazeWmRequest("query paused"), -1

; The reply's data (a Map, or "" for commands), or false on failure. A broken
; connection is reopened on the next request; the helpers restart with GlazeWM
; anyway.
GlazeWmRequest(message) {
    Critical  ; one shared connection: no other request between send and reply
    static socket := 0
    if !socket && !(socket := OpenGlazeWmSocket())
        return false
    reply := SendGlazeWmMessage(socket, message)
    if (reply = "") {
        DllCall("winhttp\WinHttpCloseHandle", "Ptr", socket)
        socket := 0
        return false
    }
    reply := ParseJson(reply)
    return reply["success"] ? reply["data"] : false
}

; A WebSocket handle, or 0. A failed step returns 0, and every later call
; then fails on the 0 handle, so only the end result needs checking.
OpenGlazeWmSocket() {
    static NO_PROXY := 1, UPGRADE_TO_WEB_SOCKET := 114
    t := GLAZEWM_IPC_TIMEOUT_MS
    session := DllCall("winhttp\WinHttpOpen", "Ptr", 0, "UInt", NO_PROXY, "Ptr", 0, "Ptr", 0, "UInt", 0, "Ptr")
    DllCall("winhttp\WinHttpSetTimeouts", "Ptr", session, "Int", t, "Int", t, "Int", t, "Int", t)
    connection := DllCall("winhttp\WinHttpConnect", "Ptr", session, "WStr", GLAZEWM_IPC_HOST,
        "UShort", GLAZEWM_IPC_PORT, "UInt", 0, "Ptr")
    request := DllCall("winhttp\WinHttpOpenRequest", "Ptr", connection, "WStr", "GET", "WStr", "/",
        "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 0, "Ptr")
    upgraded := DllCall("winhttp\WinHttpSetOption", "Ptr", request, "UInt", UPGRADE_TO_WEB_SOCKET, "Ptr", 0, "UInt", 0)
        && DllCall("winhttp\WinHttpSendRequest", "Ptr", request, "Ptr", 0, "UInt", 0, "Ptr", 0, "UInt", 0, "UInt", 0, "UPtr", 0)
        && DllCall("winhttp\WinHttpReceiveResponse", "Ptr", request, "Ptr", 0)
    socket := upgraded ? DllCall("winhttp\WinHttpWebSocketCompleteUpgrade", "Ptr", request, "UPtr", 0, "Ptr") : 0
    for handle in [request, connection, session]  ; the socket outlives them
        DllCall("winhttp\WinHttpCloseHandle", "Ptr", handle)
    return socket
}

; The reply's JSON text, or "" on a broken connection. Nothing here subscribes
; to events, so the next message from GlazeWM is the reply.
SendGlazeWmMessage(socket, message) {
    static UTF8_MESSAGE := 2, UTF8_FRAGMENT := 3
    size := StrPut(message, "UTF-8") - 1
    request := Buffer(size + 1)
    StrPut(message, request, "UTF-8")
    if DllCall("winhttp\WinHttpWebSocketSend", "Ptr", socket, "UInt", UTF8_MESSAGE, "Ptr", request, "UInt", size, "UInt")
        return ""
    reply := Buffer(64 * 1024)
    used := 0
    loop {
        if (used = reply.Size)
            reply.Size *= 2
        if DllCall("winhttp\WinHttpWebSocketReceive", "Ptr", socket, "Ptr", reply.Ptr + used,
            "UInt", reply.Size - used, "UInt*", &read := 0, "UInt*", &type := 0, "UInt")
            return ""
        used += read
        if (type != UTF8_FRAGMENT)
            return (type = UTF8_MESSAGE) ? StrGet(reply, used, "UTF-8") : ""  ; else closed
    }
}

; Objects become Maps, arrays Arrays, true/false 1/0, null "". Strings are not
; unescaped: the ids, workspace names and process names used here have no
; escapes. GlazeWM's replies are always valid JSON, so there are no checks.
ParseJson(text, &pos := 1) {
    RegExMatch(text, 'S)\G\s*([{\[]|"((?:[^"\\]|\\.)*)"|[^,:\]}\s]+)', &m, pos)
    pos += m.Len
    if (m[1] = "{" || m[1] = "[") {
        result := (m[1] = "{") ? Map() : []
        while !RegExMatch(text, 'S)\G\s*[}\]]', &closing, pos) {
            if (result is Map) {
                key := ParseJson(text, &pos)
                pos += RegExMatch(text, 'S)\G\s*:', &colon, pos) ? colon.Len : 0
                result[key] := ParseJson(text, &pos)
            } else
                result.Push(ParseJson(text, &pos))
            pos += RegExMatch(text, 'S)\G\s*,', &comma, pos) ? comma.Len : 0
        }
        pos += closing.Len
        return result
    }
    if (SubStr(m[1], 1, 1) = '"')
        return m[2]
    return (m[1] = "true") ? true : (m[1] = "false") ? false : (m[1] = "null") ? "" : Number(m[1])
}
