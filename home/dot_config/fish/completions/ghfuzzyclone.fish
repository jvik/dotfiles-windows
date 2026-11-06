complete -c ghfuzzyclone -f
complete -c ghfuzzyclone -s h -l help -d 'Show usage'
complete -c ghfuzzyclone -s r -l refresh -d 'Refetch the repo list instead of using the cache'
complete -c ghfuzzyclone -s o -l org -d 'Scope the search to a single org' -r -f -a "(gh api /user/orgs --jq '.[].login' 2>/dev/null)"
