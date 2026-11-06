#!/usr/bin/env bash
# Bootstrap the dotfiles inside WSL Ubuntu.
#
#   bash bootstrap-wsl.sh [REPO] [extra chezmoi init args...]
#
# REPO defaults to https://github.com/jvik/dotfiles-windows. A local checkout
# also works, e.g. /mnt/c/Users/<you>/repos/dotfiles-windows: it is cloned (as
# a file:// git URL) into chezmoi's default source dir ~/.local/share/chezmoi on
# the ext4 filesystem. The source dir is never /mnt/c (slow, CRLF/permissions).
#
# Installs chezmoi to ~/.local/bin via get.chezmoi.io if it's missing, then runs
# `chezmoi init --apply`, which prompts for the data values and runs the
# provisioning scripts (apt, Homebrew, mise, fish, /etc/wsl.conf; sudo prompts).
set -euo pipefail

log() { printf '\033[1;34m==>\033[0m [bootstrap-wsl] %s\n' "$*"; }

repo="${1:-https://github.com/jvik/dotfiles-windows}"
[ "$#" -gt 0 ] && shift

if ! grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
    echo "bootstrap-wsl: this does not look like WSL; aborting" >&2
    exit 1
fi

# chezmoi init clones with git; curl fetches the chezmoi installer.
missing=()
command -v git >/dev/null 2>&1 || missing+=(git)
command -v curl >/dev/null 2>&1 || missing+=(curl)
if [ "${#missing[@]}" -gt 0 ]; then
    log "installing ${missing[*]} (sudo)"
    sudo apt-get update
    sudo apt-get install -y "${missing[@]}" ca-certificates
fi

bin_dir="$HOME/.local/bin"
chezmoi="$bin_dir/chezmoi"
if [ ! -x "$chezmoi" ]; then
    log "installing chezmoi to $bin_dir"
    mkdir -p "$bin_dir"
    sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$bin_dir"
fi
export PATH="$bin_dir:$PATH"

init_args=()
if [ -d "$repo" ]; then
    # Local checkout: clone it by file:// URL and don't let chezmoi guess a
    # GitHub URL from the path.
    repo="file://$(cd "$repo" && pwd)"
    init_args+=(--guess-repo-url=false)
fi

log "chezmoi init --apply $repo"
# Never stop at a git username/password prompt: no credentials exist yet on a
# fresh distro (SSH and gh are set up by this very bootstrap), so a prompt
# always means the URL isn't anonymously cloneable.
export GIT_TERMINAL_PROMPT=0
if ! "$chezmoi" init --apply "${init_args[@]}" "$@" "$repo"; then
    cat >&2 <<EOF

bootstrap-wsl: 'chezmoi init' failed for $repo.
If the error above is about authentication/credentials, the GitHub repo is
private or not pushed yet. Either make it public, or bootstrap from the local
Windows checkout (it must be a git repo with at least one commit):

    bash $0 /mnt/c/Users/<you>/repos/dotfiles-windows

If the clone already succeeded and a later step failed, fix it and run
'chezmoi apply' instead of re-running this script.
EOF
    exit 1
fi
