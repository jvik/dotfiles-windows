# Git worktree fuzzy selector
function git-fworktree -d "Fuzzy select and cd into git worktree"
    set worktree (git worktree list | fzf | awk '{print $1}')
    and cd $worktree
end
