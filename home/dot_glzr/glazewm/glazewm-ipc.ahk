; Shared by helpers that talk to GlazeWM (obsidian.ahk): sends messages to
; GlazeWM's IPC WebSocket and parses the JSON replies.
;
; The glazewm CLI does the same, but each call starts a process and connects
; anew, about 400 ms here. Over one connection kept open, a query takes
; 15-60 ms. WinHTTP's WebSocket API, called with DllCall, needs nothing
; installed. "127.0.0.1", not "localhost": that tries IPv6 first and takes
; seconds to fall back.
;
; Messages are the CLI's arguments as one string: "query workspaces",
; "command --id <container id> move --workspace 4".
;
; Included by helpers.ahk; not meant to run on its own.

GLAZEWM_IPC_HOST := "127.0.0.1"
GLAZEWM_IPC_PORT := 6123
GLAZEWM_IPC_TIMEOUT_MS := 2000

; Connect now, while no hotkey waits for it: the first request takes about
; 400 ms, later ones on the same connection a few ms. If GlazeWM is not
; ready yet, the first real request connects instead.
SetTimer () => GlazeWmRequest("query paused"), -1

; The reply's data (a Map, or "" for commands), or false when GlazeWM could
; not be reached or the message failed.
GlazeWmRequest(message) {
    ; One connection is shared, so another thread must not send its message
    ; before this one has read its reply.
    Critical
    static socket := 0
    loop 2 {  ; a second try on a fresh connection, after GlazeWM restarted
        if !socket
            socket := OpenGlazeWmSocket()
        if !socket
            return false
        reply := SendGlazeWmMessage(socket, message)
        if (reply != "")
            break
        DllCall("winhttp\WinHttpCloseHandle", "Ptr", socket)
        socket := 0
    }
    if (reply = "")
        return false
    reply := ParseJson(reply)
    return reply["success"] ? reply["data"] : false
}

; A WebSocket handle, or 0. The session and connection handles may be closed
; once the socket exists.
OpenGlazeWmSocket() {
    static WINHTTP_ACCESS_TYPE_NO_PROXY := 1
    static WINHTTP_OPTION_UPGRADE_TO_WEB_SOCKET := 114
    session := DllCall("winhttp\WinHttpOpen", "Ptr", 0, "UInt", WINHTTP_ACCESS_TYPE_NO_PROXY,
        "Ptr", 0, "Ptr", 0, "UInt", 0, "Ptr")
    if !session
        return 0
    timeout := GLAZEWM_IPC_TIMEOUT_MS
    DllCall("winhttp\WinHttpSetTimeouts", "Ptr", session, "Int", timeout, "Int", timeout,
        "Int", timeout, "Int", timeout)
    socket := 0
    connection := DllCall("winhttp\WinHttpConnect", "Ptr", session, "WStr", GLAZEWM_IPC_HOST,
        "UShort", GLAZEWM_IPC_PORT, "UInt", 0, "Ptr")
    request := connection ? DllCall("winhttp\WinHttpOpenRequest", "Ptr", connection, "WStr", "GET",
        "WStr", "/", "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", 0, "Ptr") : 0
    if request
        && DllCall("winhttp\WinHttpSetOption", "Ptr", request, "UInt", WINHTTP_OPTION_UPGRADE_TO_WEB_SOCKET,
            "Ptr", 0, "UInt", 0)
        && DllCall("winhttp\WinHttpSendRequest", "Ptr", request, "Ptr", 0, "UInt", 0,
            "Ptr", 0, "UInt", 0, "UInt", 0, "UPtr", 0)
        && DllCall("winhttp\WinHttpReceiveResponse", "Ptr", request, "Ptr", 0)
        socket := DllCall("winhttp\WinHttpWebSocketCompleteUpgrade", "Ptr", request, "UPtr", 0, "Ptr")
    for handle in [request, connection, session] {
        if handle
            DllCall("winhttp\WinHttpCloseHandle", "Ptr", handle)
    }
    return socket
}

; The reply's JSON text, or "" on a broken connection. GlazeWM only sends
; replies (nothing here subscribes to events), so the next message is ours.
SendGlazeWmMessage(socket, message) {
    static UTF8_MESSAGE := 2   ; WINHTTP_WEB_SOCKET_BUFFER_TYPE values
    static UTF8_FRAGMENT := 3
    size := StrPut(message, "UTF-8") - 1
    request := Buffer(size + 1)
    StrPut(message, request, "UTF-8")
    if DllCall("winhttp\WinHttpWebSocketSend", "Ptr", socket, "UInt", UTF8_MESSAGE,
        "Ptr", request, "UInt", size, "UInt")
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
        if (type = UTF8_MESSAGE)
            return StrGet(reply, used, "UTF-8")
        if (type != UTF8_FRAGMENT)
            return ""  ; closed by GlazeWM
    }
}

; Objects become Maps, arrays Arrays; true and false become 1 and 0, null
; becomes "". Enough for GlazeWM's replies, which are always valid JSON.
ParseJson(text) {
    tokens := TokenizeJson(text)
    i := 1
    return ParseJsonValue(tokens, &i)
}

; A token is either {punct: one of {}[],:} or {value: string, number, 1, 0
; or ""}.
TokenizeJson(text) {
    static pattern := 'S)\G\s*(?:([{}\[\],:])|"((?:[^"\\]|\\.)*)"|(true|false|null|-?[0-9][0-9.eE+-]*))'
    tokens := []
    pos := 1
    while RegExMatch(text, pattern, &m, pos) {
        pos += m.Len
        first := SubStr(LTrim(m[0]), 1, 1)
        if InStr("{}[],:", first)
            tokens.Push({punct: first})
        else if (first = '"')
            tokens.Push({value: UnescapeJson(m[2])})
        else if (m[3] = "true")
            tokens.Push({value: true})
        else if (m[3] = "false")
            tokens.Push({value: false})
        else if (m[3] = "null")
            tokens.Push({value: ""})
        else
            tokens.Push({value: Number(m[3])})
    }
    return tokens
}

ParseJsonValue(tokens, &i) {
    token := tokens[i++]
    if !token.HasOwnProp("punct")
        return token.value
    if (token.punct = "{") {
        obj := Map()
        if IsJsonPunct(tokens[i], "}") {
            i++
            return obj
        }
        loop {
            key := tokens[i].value
            i += 2  ; the key and its ":"
            obj[key] := ParseJsonValue(tokens, &i)
            if (tokens[i++].punct = "}")
                return obj
        }
    }
    if (token.punct = "[") {
        arr := []
        if IsJsonPunct(tokens[i], "]") {
            i++
            return arr
        }
        loop {
            arr.Push(ParseJsonValue(tokens, &i))
            if (tokens[i++].punct = "]")
                return arr
        }
    }
    throw Error("unexpected JSON token: " token.punct)
}

IsJsonPunct(token, char) {
    return token.HasOwnProp("punct") && (token.punct = char)
}

UnescapeJson(s) {
    static escapes := Map("b", "`b", "f", "`f", "n", "`n", "r", "`r", "t", "`t")
    if !InStr(s, "\")
        return s
    out := ""
    pos := 1
    while RegExMatch(s, "\\(u[0-9a-fA-F]{4}|.)", &m, pos) {
        out .= SubStr(s, pos, m.Pos - pos)
        escaped := m[1]
        if (StrLen(escaped) = 5)
            out .= Chr(Integer("0x" SubStr(escaped, 2)))
        else
            out .= escapes.Has(escaped) ? escapes[escaped] : escaped  ; \" \\ \/
        pos := m.Pos + m.Len
    }
    return out SubStr(s, pos)
}
