# Repo helper recipes. Works from both sides:
#   WSL:     run in ~/.local/share/chezmoi (the WSL source clone); uses bash
#   Windows: run in the repo root (chezmoi's persisted sourceDir); uses
#            Windows PowerShell 5.1, so recipe lines must stay 5.1-compatible
# Each side drives its own chezmoi, so recipes act on that side's home only.
# (Running just in /mnt/c/... from WSL talks to the WSL chezmoi, whose source
# is the ext4 clone, not this checkout.)

set shell := ["bash", "-euo", "pipefail", "-c"]
# Deprecated in just >= 1.56 in favour of `[windows]` on `set shell`, but kept
# because it works on every just version.
set windows-shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-Command"]

default:
    @just --list

# Preview what chezmoi would change (read-only); optionally limited to targets
diff *targets:
    chezmoi diff {{ targets }}

# Dry-run apply
check:
    chezmoi apply --dry-run --verbose

# Apply one source file; avoids a bare apply, which can revert unrelated live edits
[unix]
apply source:
    chezmoi apply --verbose "$(chezmoi target-path '{{ source }}')"

# Apply one source file; avoids a bare apply, which can revert unrelated live edits
[windows]
apply source:
    chezmoi apply --verbose (chezmoi target-path '{{ source }}')

# Apply everything (files, externals and any run_onchange_ scripts whose input changed)
apply-all:
    chezmoi apply --verbose

# Pull the repo and apply (git pull --autostash --rebase in the source dir, then apply)
update:
    chezmoi update --verbose

# Edit managed files in the source state (no args: open the source dir)
edit *targets:
    chezmoi edit {{ targets }}

# Run only the scripts: installs whatever changed in home/.chezmoidata/packages.yaml (winget on Windows, apt/brew/mise in WSL)
packages:
    chezmoi apply --include scripts --verbose

# Upgrade everything with topgrade (Windows: winget + topgrade inside WSL; WSL: apt, brew, mise, plugins)
upgrade *args:
    topgrade {{ args }}

# Show what topgrade would do
upgrade-check:
    topgrade --dry-run

# chezmoi's own health check
doctor:
    chezmoi doctor

# Show the template data this side sees (isWindows/isWSL, features, ...)
data:
    chezmoi data

# Everything to check before handoff
validate: diff check
