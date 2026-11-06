function cleanprompt
    if set -q CLEANPROMPT
        set -e CLEANPROMPT
    else
        set -gx CLEANPROMPT 1
    end
end
