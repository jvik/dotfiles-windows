# Resolve a host once, then hit it repeatedly pinned to that IP via curl
# --resolve, printing the HTTP status and timing for each attempt. Useful for
# checking whether a specific backend behind a DNS/CDN name is healthy.
function httpcheck --description 'Repeatedly curl a host pinned to one resolved IP'
    argparse 'n/count=' 'p/port=' 's/scheme=' 't/timeout=' 'h/help' -- $argv
    or return 1

    if set -q _flag_help
        echo "httpcheck [-n count] [-p port] [-s http|https] [-t timeout] <host>"
        echo
        echo "  Resolve <host> once, then curl it that many times pinned to that"
        echo "  IP via --resolve, printing the HTTP status and timing per attempt."
        echo
        echo "  -n, --count    number of requests (default 5)"
        echo "  -p, --port     port to pin in --resolve (default 443)"
        echo "  -s, --scheme   http or https (default https)"
        echo "  -t, --timeout  curl --max-time in seconds (default 20)"
        return 0
    end

    set -q argv[1]
    or begin
        echo "httpcheck: missing host" >&2
        return 1
    end
    set -l host $argv[1]

    set -q _flag_count
    or set _flag_count 5
    set -q _flag_port
    or set _flag_port 443
    set -q _flag_scheme
    or set _flag_scheme https
    set -q _flag_timeout
    or set _flag_timeout 20

    if not type -q dig
        echo "httpcheck: dig is not installed" >&2
        return 1
    end

    set -l ip (dig +short $host | grep -E '^[0-9.]+$' | head -n1)
    if test -z "$ip"
        echo "httpcheck: could not resolve $host to an IPv4 address" >&2
        return 1
    end
    echo "Using IP: $ip"

    for i in (seq $_flag_count)
        curl -o /dev/null -s -w "attempt $i: code=%{http_code} exit=%{exitcode} total=%{time_total}s connect=%{time_connect}s tls=%{time_appconnect}s ttfb=%{time_starttransfer}s\n" \
            --max-time $_flag_timeout \
            --resolve "$host:$_flag_port:$ip" \
            "$_flag_scheme://$host"
    end
end
