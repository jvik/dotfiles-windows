function fish_title
    if set -q CLEANPROMPT
        echo fish
        return
    end
    set -l k8s_ctx ""
    if type -q kubectl
        set k8s_ctx (kubectl config current-context 2>/dev/null)
    end
    if test -n "$k8s_ctx"
        echo (whoami)@(prompt_hostname) "| k8s:"$k8s_ctx
    else
        echo (whoami)@(prompt_hostname)
    end
end
