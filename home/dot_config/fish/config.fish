# Fish Shell Configuration
# Main config file for Fish shell (WSL2 Ubuntu; chezmoi only deploys it there)

# Source environment variables (PATH, Homebrew, mise)
source $HOME/.config/fish/env.fish

# Source abbreviations
source $HOME/.config/fish/abbr.fish

# Source aliases
source $HOME/.config/fish/aliases.fish

# Source key bindings
source $HOME/.config/fish/keybindings.fish

# Source functions are automatically loaded from functions/ directory

# Enable Vi mode
fish_vi_key_bindings

# Restore fzf bindings after vi mode (vi mode resets all key bindings)
if functions -q fzf_configure_bindings
    fzf_configure_bindings
end

# Explicitly bind Ctrl+R for fzf history search in vi insert and normal mode
if functions -q _fzf_search_history
    bind -M insert \cr _fzf_search_history
    bind \cr _fzf_search_history
end


# Color scheme and syntax highlighting
set -g fish_color_normal normal
set -g fish_color_command blue
set -g fish_color_keyword magenta
set -g fish_color_quote yellow
set -g fish_color_redirection cyan
set -g fish_color_end green
set -g fish_color_error red --bold
set -g fish_color_param cyan
set -g fish_color_comment brblack
set -g fish_color_match --background=brblue --bold
set -g fish_color_selection white --bold --background=brblack
set -g fish_color_search_match bryellow --background=brblack
set -g fish_color_operator brcyan
set -g fish_color_escape brcyan
set -g fish_color_autosuggestion brblack

# Pager colors
set -g fish_pager_color_prefix cyan --bold --underline
set -g fish_pager_color_completion normal
set -g fish_pager_color_description yellow
set -g fish_pager_color_progress brwhite --background=cyan

# Disable greeting
set -g fish_greeting

# History
set -g fish_history_file $XDG_CACHE_HOME/fish_history

# Initialize tools
# (Homebrew shellenv and mise activation live in env.fish, before anything
# that needs the tools they put on PATH.)
if type -q zoxide
    zoxide init fish | source
end

# WSL-specific configuration: Windows interop PATH, wsl-open, SSH agent bridge.
# Sourced before local.fish so local.fish can still override it.
if set -q WSL_DISTRO_NAME; and test -f $HOME/.config/fish/wsl.fish
    source $HOME/.config/fish/wsl.fish
end

# Load local config if it exists
if test -f $HOME/.config/fish/local.fish
    source $HOME/.config/fish/local.fish
end
