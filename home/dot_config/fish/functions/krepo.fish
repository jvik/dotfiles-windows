# Fuzzy find a repo in $gh_org and open it in the browser
function krepo --description 'Fuzzy find a GitHub repo and open it in the browser'
    set -l cache $XDG_CACHE_HOME/krepo/repos.json
    set -q gh_repo_browser; or set -l gh_repo_browser wsl-open

    if not test -f $cache
        krepo-update
        or return 1
    end

    set -l url (jq -r '.[] | "\(.name)\t\(.url)"' $cache \
        | fzf --delimiter='\t' --with-nth=1 \
        | cut -f2)

    test -n "$url"
    and $gh_repo_browser $url
end

# Refresh the cached repo list that krepo fuzzy-searches
function krepo-update --description 'Refresh cached list of GitHub repos for krepo'
    if not set -q gh_org
        echo "gh_org not set. Add 'set -gx gh_org <org>' to ~/.config/fish/local.fish" >&2
        return 1
    end

    mkdir -p $XDG_CACHE_HOME/krepo
    gh repo list $gh_org --limit 1000 --json name,url >$XDG_CACHE_HOME/krepo/repos.json
    or return 1

    echo "krepo cache updated: "(jq length $XDG_CACHE_HOME/krepo/repos.json)" entries"
end
