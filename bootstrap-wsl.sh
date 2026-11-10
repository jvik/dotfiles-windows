#!/usr/bin/env bash
# Bootstrap the dotfiles inside WSL Ubuntu, from the Windows checkout:
#
#   bash /mnt/c/Users/<you>/repos/dotfiles-windows/bootstrap-wsl.sh [extra chezmoi init args...]
#
# WSL's chezmoi uses the checkout this script lives in as its source, through
# /mnt/c; there is no second clone. Afterwards `chezmoi apply` on Windows also
# applies WSL (home/.chezmoiscripts/windows/run_after_90-wsl-apply).
#
# Installs curl if missing and chezmoi to ~/.local/bin via get.chezmoi.io, then
# runs `chezmoi init --apply --source <checkout>`, which prompts for the data
# values and runs the provisioning scripts (apt, Homebrew, mise, fish,
# /etc/wsl.conf; sudo prompts).
set -euo pipefail

log() { printf '\033[1;34m==>\033[0m [bootstrap-wsl] %s\n' "$*"; }

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
    echo "bootstrap-wsl: this does not look like WSL; aborting" >&2
    exit 1
fi
if [ ! -f "$repo/.chezmoiroot" ]; then
    echo "bootstrap-wsl: $repo has no .chezmoiroot; run this script from the dotfiles-windows checkout" >&2
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    log "installing curl (sudo)"
    sudo apt-get update
    sudo apt-get install -y curl ca-certificates
fi

bin_dir="$HOME/.local/bin"
chezmoi="$bin_dir/chezmoi"
if [ ! -x "$chezmoi" ]; then
    log "installing chezmoi to $bin_dir"
    mkdir -p "$bin_dir"
    sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$bin_dir"
fi
export PATH="$bin_dir:$PATH"

log "chezmoi init --apply --source $repo"
if ! "$chezmoi" init --apply --source "$repo" "$@"; then
    cat >&2 <<EOF

bootstrap-wsl: 'chezmoi init --apply' failed; see the error above. Fix it,
then run 'chezmoi apply' on Windows (it applies WSL too) or re-run this script.
EOF
    exit 1
fi
