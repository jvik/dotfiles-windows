# Fuzzy find every abbreviation, alias and custom function, then put the chosen
# name on the command line so it expands on <space>. The terminal counterpart to
# PowerToys Shortcut Guide on the Windows side.
function ab --description 'Fuzzy find abbreviations, aliases and functions'
    argparse n/dump h/help -- $argv
    or return 1

    if set -q _flag_help
        echo "ab [-n|--dump] [query]"
        echo
        echo "  Fuzzy find abbreviations, aliases and custom functions."
        echo "  Selecting an entry puts its name on the command line."
        echo
        echo "  -n, --dump    print the parsed rows instead of opening the picker"
        return 0
    end

    if set -q _flag_dump
        _ab_rows
        return 0
    end

    if not type -q fzf
        echo "ab: fzf is not installed" >&2
        return 1
    end

    set -l rows (_ab_rows)

    # Width of the name column, so the value column lines up. Done with one
    # vectorized call per step rather than a loop -- at 10k abbreviations a
    # per-row loop costs 190ms here instead of 12ms.
    set -l width (string length -- (string split -f2 \t -- $rows) | sort -rn | head -1)
    test -n "$width"
    or set width 0
    test $width -gt 20
    and set width 20

    # display \t name \t value -- fzf shows field 1, previews field 3, and we
    # insert field 2. awk formats all rows in a single pass: building the lines
    # in a fish loop meant four command substitutions per row plus an O(n^2)
    # `set -a`, which is what made 10k abbreviations take four seconds. awk's
    # printf takes a variable field width (%-*s); fish's builtin printf cannot.
    set -l picked (printf '%s\n' $rows \
        | awk -F\t -v w=$width '{ printf "%-5s %-*s  %s\t%s\t%s\n", $1, w, $2, $3, $2, $3 }' \
        | fzf --delimiter=\t --with-nth=1 \
            --height 60% --reverse --border --border-label ' abbreviations ' \
            --prompt 'ab  ' \
            --preview 'echo {3}' --preview-window 'down,3,wrap' \
            --query "$argv" \
        | string split -f2 \t)

    test -n "$picked"
    or return 0

    if status is-interactive
        commandline -r -- $picked
    else
        echo $picked
    end
end

# Emit "kind<tab>name<tab>value" for every abbreviation, alias and custom
# function. Everything is read at invocation time, so there is no list to keep
# in sync.
function _ab_rows --description 'Collect abbreviation, alias and function rows for ab'
    # `abbr --show` prints valid fish source, e.g. abbr -a -- gcm 'git commit -m'.
    # One vectorized pass over the whole stream, not a loop: at 10k abbreviations
    # a per-line loop costs 430ms against 22ms here.
    #
    # --filter is load-bearing: string replace passes non-matching lines through
    # unchanged, so without it a valueless abbreviation (abbr --function) would
    # leak its raw source line into the output as a bogus row.
    #
    # Unescaping whole lines is safe. The \t in the replacement is a literal
    # backslash-t that unescape turns into a real tab, and it strips the value's
    # quoting in the same pass -- abbr --show writes backslashes as \\, which
    # unescape reverses, so values like `printf a\tb` survive intact. The .*? is
    # what lets --position/--regex flags sit between `abbr` and `--`.
    abbr --show \
        | string replace -rf '^abbr\s.*?\s--\s(\S+)\s(.*)$' 'abbr\t$1\t$2' \
        | string unescape --style=script

    # Files owned by fisher plugins, so their helpers stay out of the list.
    # Fisher records them in universal variables, with $HOME written as "~".
    set -l plugin_files
    for var in (set --names | string match -r '^_fisher_.+_files$')
        for file in $$var
            set -a plugin_files (string replace -r '^~' $HOME -- $file)
        end
    end

    # An autoloadable file only advertises the function named after it, so touch
    # each of ours first -- that loads the file and reveals any extra function
    # it defines (krepo-update lives in krepo.fish).
    for file in $__fish_config_dir/functions/*.fish
        functions --query (path basename (path change-extension '' $file))
    end

    # Aliases and functions come out of one pass -- an alias is just a function
    # that fish gave a description of the form "alias name=value" -- but they
    # are buffered so each kind prints as its own block.
    set -l aliases
    set -l fns

    for name in (functions --names)
        string match -q -- '_*' $name
        and continue
        string match -q 'fish_*' -- $name
        and continue

        # 1: definition file, 2: autoloaded, 3: line, 4: scope, 5: description
        set -l info (functions --details --verbose $name)
        test (count $info) -eq 5
        or continue
        test -n "$info[5]"
        or continue

        # Read the alias out of the description rather than asking `alias`,
        # which silently skips any alias whose value contains a single quote
        # (its listing only matches single-quoted descriptions).
        set -l m (string match -r '^alias\s[^=]+=(.*)$' -- $info[5])
        if test (count $m) -eq 2
            set -a aliases (printf 'alias\t%s\t%s' $name $m[2])
            continue
        end

        # Only our own functions: this also excludes fish's shipped ones (ls,
        # help, math, seq, ...), which have descriptions of their own.
        string match -q -- "$__fish_config_dir/functions/*" $info[1]
        or continue
        contains -- $info[1] $plugin_files
        and continue

        set -a fns (printf 'fn\t%s\t%s' $name $info[5])
    end

    for row in $aliases $fns
        echo $row
    end
end
