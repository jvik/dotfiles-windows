# Fuzzy clone GitHub repository
function ghfuzzyclone -d "Fuzzy search and clone a GitHub repository from your account, orgs, and shared repos"
    argparse 'o/org=' 'r/refresh' 'h/help' -- $argv
    or return 1

    if set -q _flag_help
        echo "ghfuzzyclone [-o|--org ORG] [-r|--refresh]"
        echo
        echo "  Fuzzy search and clone a GitHub repo. Repos are cached under"
        echo "  \$XDG_CACHE_HOME/ghfuzzyclone/; use --refresh to update the cache."
        echo
        echo "  -o, --org ORG   scope the search to a single org instead of"
        echo "                  your account, orgs, and shared repos"
        echo "  -r, --refresh   refetch the repo list instead of using the cache"
        return 0
    end

    if not type -q fzf
        echo "ghfuzzyclone: fzf is not installed" >&2
        return 1
    end

    set -l scope all
    set -q _flag_org
    and set -l scope $_flag_org

    set -l cache_dir $XDG_CACHE_HOME/ghfuzzyclone
    set -l cache $cache_dir/$scope.json

    if set -q _flag_refresh; or not test -f $cache
        mkdir -p $cache_dir
        if set -q _flag_org
            gh repo list $_flag_org --limit 1000 --json nameWithOwner,description \
                | jq '[.[] | {full_name: .nameWithOwner, description: .description}]' >$cache
        else
            gh api '/user/repos?affiliation=owner,organization_member,collaborator' --paginate >$cache
        end
        or return 1
    end

    set -l repo (jq -r '.[] | "\(.full_name)\t\(.description // "")"' $cache \
        | fzf --delimiter='\t' --with-nth=1 --preview 'echo {}' --preview-window 'down,3,wrap' \
        | awk '{print $1}')

    test -n "$repo"
    and gh repo clone $repo
end
