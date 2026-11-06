# Copy to clipboard (in WSL: the Windows clipboard)
# Reads the given file(s), or stdin when called without arguments.
function copy -d "Copy content to clipboard"
    if type -q win32yank.exe
        cat $argv | win32yank.exe -i --crlf
    else if type -q clip.exe
        # clip.exe reads the input in the console codepage; feed it UTF-16LE
        # or non-ASCII text such as æøå gets mangled.
        cat $argv | iconv -f UTF-8 -t UTF-16LE | clip.exe
    else
        rm -f /tmp/clipboard 2>/dev/null
        cat $argv >/tmp/clipboard
    end
end
