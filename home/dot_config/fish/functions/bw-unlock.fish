function bw-unlock --description "Unlock Bitwarden and export BW_SESSION for this shell"
    # Uses the bw CLI inside WSL (brew bitwarden-cli), the same one scripts and
    # SOPS_AGE_KEY_CMD invoke, so BW_SESSION is valid for them too. Note: it is a
    # separate login from Bitwarden Desktop on Windows.
    set -l bw
    if command -q bw
        set bw bw
    else
        echo "Bitwarden CLI not found (install bitwarden-cli with brew)." >&2
        return 1
    end

    # Already unlocked and session still valid? Reuse it.
    if set -q BW_SESSION; and $bw unlock --check --session $BW_SESSION >/dev/null 2>&1
        echo "Bitwarden already unlocked (BW_SESSION set)."
        $bw sync --session $BW_SESSION >/dev/null; and echo "Bitwarden vault synced."
        return 0
    end

    # Must be logged in first.
    set -l login_status ($bw login --check 2>&1)
    if string match -q "*not logged in*" -- $login_status
        echo "Not logged in to Bitwarden. Run: $bw login" >&2
        return 1
    end

    # Unlock; --raw prints only the session key. `login --check` only reads
    # local state, so an expired/revoked refresh token (server replies
    # invalid_grant) only surfaces here -- a fresh login fixes it.
    set -l token ($bw unlock --raw)
    set -l unlock_status $status
    if test $unlock_status -ne 0; or test -z "$token"
        echo "Bitwarden unlock failed. If you saw 'invalid_grant' or 'Unable to retrieve user-key'," >&2
        echo "the stored login is stale. Re-login with: $bw logout; and $bw login" >&2
        return 1
    end

    set -gx BW_SESSION $token
    echo "BW_SESSION exported for this shell (via $bw)."

    $bw sync >/dev/null; and echo "Bitwarden vault synced."
end
