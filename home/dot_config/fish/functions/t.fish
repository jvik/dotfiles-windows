# Session manager with fzf
function t -d "Sesh session manager with fzf"
    set session (sesh list -t -c | fzf --height 40% --reverse --border-label ' sesh ' --border --prompt '⚡  ')
    and sesh connect $session
end
