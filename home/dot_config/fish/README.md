# Fish Shell Configuration

A comprehensive Fish shell configuration ported from ZSH with modern features and enhancements.

## Features

### ✨ Enabled Features

- **Syntax Highlighting**: Built-in syntax highlighting with custom color scheme
- **Autosuggestions**: Fish's intelligent command autosuggestions (built-in)
- **Vi Mode**: Vi keybindings enabled by default
- **Smart History**: Contextual command history with 10,000 entries
- **Fast Startup**: Optimized loading and lazy initialization
- **Tab Completions**: Rich tab completions for common tools

### 🎨 Syntax Highlighting

Fish comes with syntax highlighting built-in. This configuration includes:
- Custom color scheme optimized for visibility
- Command validation (red for invalid commands)
- Quoted string highlighting
- Path autocompletion highlighting

### 📦 Integrations

- **Zoxide**: Fast directory jumping (z command)
- **Homebrew**: Linuxbrew `shellenv`, only if `/home/linuxbrew/.linuxbrew/bin/brew` exists
- **mise**: `mise activate fish` for the version-pinned tools (node, kubectl, helm, ...)
- **WSL interop**: selected Windows dirs on PATH, `open`/`$BROWSER` via `wsl-open`, Windows clipboard in `copy`/`pasta`
- **SSH agent**: `wsl2-ssh-agent` bridges the Bitwarden Desktop agent on Windows into `SSH_AUTH_SOCK`
- **FZF**: Fuzzy finding integration
- **Eza**: Modern ls replacement with icons
- **Kubectl**: Kubernetes command completions
- **Git**: Enhanced git integrations

## File Structure

```
~/.config/fish/
├── config.fish           # Main configuration file
├── env.fish             # Environment variables, PATH, Homebrew, mise
├── abbr.fish            # Command abbreviations (expand on space)
├── aliases.fish         # Traditional aliases
├── keybindings.fish     # Key binding tweaks
├── wsl.fish             # WSL-specific settings (Windows PATH, wsl-open, SSH agent)
├── fish_plugins         # Fisher plugin list
├── local.fish.example   # Example local configuration
└── functions/           # Custom functions
    ├── mkcd.fish
    ├── tempe.fish
    ├── pasta.fish
    ├── copy.fish
    ├── fvim.fish
    ├── ghfuzzyclone.fish
    ├── t.fish
    ├── krepo.fish
    └── git-fworktree.fish
```

## Abbreviations vs Aliases

Fish uses **abbreviations** which expand when you press space (like ZSH aliases), and traditional **aliases** for runtime replacements.

### Key Abbreviations

- `..`, `2..`, `3..`, etc. - Navigate up directories
- `k` - kubectl
- `ka` - kubectl apply -f
- `kg` - kubectl get
- `l` - eza with icons and git status
- `lt` - eza tree view
- `:q`, `q` - exit shell

### Custom Functions

- `mkcd <dir>` - Create directory and cd into it
- `tempe [subdir]` - Create secure temp directory and cd
- `fvim` - Fuzzy find and open file in nvim
- `t` - Sesh session manager with fzf
- `git-fworktree` - Fuzzy select git worktree
- `ghfuzzyclone` - Fuzzy clone a GitHub repo from your personal account, every org you belong to, and repos shared with you as a collaborator. Caches the repo list under `$XDG_CACHE_HOME/ghfuzzyclone/`; `-o/--org ORG` scopes to one org, `-r/--refresh` updates the cache
- `krepo` - Fuzzy find a repo in `$gh_org` and open it in the browser
- `krepo-update` - Refresh the cached repo list (defined in `krepo.fish`)
- `pasta` - Paste from the Windows clipboard (`win32yank.exe`, falls back to `powershell.exe Get-Clipboard`)
- `copy [file]` - Copy stdin or a file to the Windows clipboard (`win32yank.exe`, falls back to `clip.exe`)
- `hr` - Attach to herdr with a workspace for the current directory (only with the agent-sandbox feature)

## Installation

Everything is provisioned by chezmoi inside WSL (see the repo README): fish comes from
apt (fish-shell/release-4 PPA) and is made the login shell with `chsh -s /usr/bin/fish`;
the CLIs (eza, zoxide, fzf, fd, bat, gh, sesh, ...) come from Homebrew; version-pinned
tools (including `wsl2-ssh-agent`) come from mise. `win32yank.exe` is installed on the
Windows side with winget and reached through the WinGet Links dir that `wsl.fish` puts on PATH.

### Plugins

Fisher plugins are listed in `fish_plugins` and installed by `fisher update`, which
chezmoi re-runs whenever that file changes:

- `jorgebucaran/fisher` - the plugin manager itself
- `PatrickF1/fzf.fish` - fzf integration (Ctrl+R history, file and git pickers)
- `lewisacidic/fish-git-abbr` - git abbreviations

Add a plugin by adding it to `fish_plugins` in the chezmoi source (or `fisher install` and
`chezmoi re-add ~/.config/fish/fish_plugins`).

## Customization

### Local Configuration

Create `~/.config/fish/local.fish` for machine-specific settings:

```fish
# Example local.fish
set -gx CUSTOM_PATH /my/custom/path
fish_add_path -p /my/custom/path
```

### Theme Customization

Fish supports themes through the `fish_config` web interface:

```bash
fish_config
```

The prompt itself is `functions/fish_prompt.fish` (its git dirty check is skipped under
`/mnt/*`, where git over 9P is slow; keep repos in the WSL home, e.g. `~/src`).

## Migration from ZSH

All your ZSH aliases, functions, and environment variables have been ported. Key differences:

- `source` → Fish auto-sources functions from `functions/` directory
- `export VAR=value` → `set -gx VAR value`
- `alias` → Use `abbr` for expanding aliases, `alias` for runtime
- `function() { }` → `function name; ...; end`

## Shortcut picker

`ab` fuzzy-finds every abbreviation, alias and custom function and puts the chosen **name** on
the command line, so `<space>` expands it and you learn the shortcut instead of just running it.
This is the terminal counterpart to PowerToys Shortcut Guide on the Windows side.

```bash
ab              # open the picker
ab kube         # open it pre-filtered
ab --dump       # print the parsed rows, no picker (useful for debugging)
```

The list is built from `abbr --show`, `alias` and `functions` at invocation time, so there is no
cheatsheet to keep in sync. It covers far more than `abbr.fish`: of ~229 entries, only ~65 are
defined here — the rest come from the `lewisacidic/fish-git-abbr` plugin.

Rows are `kind  name  expansion`, grouped as abbreviations, then aliases, then functions. fzf
matches against the expansion too, so searching `commit` finds `gcm`.

## Tips

1. **Reload Config**: `reload-fish` or `source ~/.config/fish/config.fish`
2. **View Abbreviations**: `ab` (fuzzy picker) or `abbr` (raw list)
3. **View Functions**: `ab` or `functions` (list all)
4. **Help System**: `help <command>` opens browser with docs
5. **Syntax Check**: `fish -n config.fish`

## Performance

Fish is designed to be fast:
- Syntax highlighting is instant
- Completions are generated on-demand
- Functions are lazy-loaded from files
- Startup time should be < 100ms

## Troubleshooting

### Slow Startup

Check what's loading:
```bash
fish --profile config.fish
```

### Missing Features

Ensure tools are installed:
```bash
type -q eza zoxide fzf; and echo "All installed" || echo "Missing tools"
```

## Resources

- [Fish Documentation](https://fishshell.com/docs/current/)
- [Fish Tutorial](https://fishshell.com/docs/current/tutorial.html)
- [Awesome Fish](https://github.com/jorgebucaran/awsm.fish)
