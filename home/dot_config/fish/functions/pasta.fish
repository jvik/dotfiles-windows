# Paste from clipboard (in WSL: the Windows clipboard)
function pasta -d "Paste content from clipboard"
    if type -q win32yank.exe
        win32yank.exe -o --lf
    else if type -q powershell.exe
        # Slow (~300ms+) fallback. Force UTF-8 output so æøå survive, and drop
        # the CRs Windows line endings leave behind.
        powershell.exe -NoProfile -NonInteractive -Command '[Console]::OutputEncoding = [Text.Encoding]::UTF8; Get-Clipboard' \
            | string replace -a \r ''
    else if test -e /tmp/clipboard
        cat /tmp/clipboard
    else
        echo ''
    end
end
