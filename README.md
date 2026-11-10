# dotfiles-windows

Work machine setup for Windows 11 + WSL2 Ubuntu, managed by
[chezmoi](https://www.chezmoi.io/). One checkout, applied to both sides:

* **Windows**: `chezmoi.exe` targets `%USERPROFILE%`. It manages WezTerm,
  `.wslconfig`, topgrade, git, the Claude Code settings, winget packages,
  the PowerToys remaps and the Obsidian vimrc.
* **WSL**: `chezmoi` inside Ubuntu targets `~`. It manages fish, tmux,
  nvim/LazyVim, mise, git, the apt/Homebrew/mise packages, `/etc/wsl.conf`,
  Docker Engine, herdr and agent-sandbox.

Both read the same Windows checkout (WSL through `/mnt/c`), and a full
`chezmoi apply` on Windows ends by applying WSL too
([One apply for both sides](#one-apply-for-both-sides)).

Successor of the Linux/sway repo [jvik/dotfiles](https://github.com/jvik/dotfiles):
the shell, editor and agent habits carry over, while the desktop and the
Ansible bootstrap do not (see [What was dropped](#what-was-dropped-from-the-linux-repo)).

> Goal: one script per side brings a fresh machine to a comfortable, fully configured environment.

---

## Layout

`.chezmoiroot` contains `home`, so the chezmoi source state is `home/`.
Everything at the repo root is repo-only and never deployed: this README,
`AGENTS.md`, `CLAUDE.md`, `justfile`, `bootstrap.ps1`, `bootstrap-wsl.sh`,
`.gitattributes`, `.github/` and `.vscode/`.

```text
home/
  .chezmoi.yaml.tmpl      config template; the ONLY file that looks at the OS
  .chezmoidata/packages.yaml   winget / apt / brew package lists
  .chezmoidata/powertoys.yaml  PowerToys Keyboard Manager remaps
  .chezmoiignore          which targets each side skips (isWindows / isWSL / features)
  .chezmoiexternal.toml.tmpl   tpm (tmux plugin manager, WSL), arkenfox user.js (Windows)
  .chezmoiscripts/windows/*.ps1.tmpl   Windows install/check scripts
  .chezmoiscripts/linux/*.sh.tmpl      WSL provisioning scripts
  .chezmoitemplates/      Claude settings defaults, shared skill, obsidian.vimrc, Firefox overrides
  AppData/Roaming/        %APPDATA% (topgrade.toml)
  dot_config/ dot_local/ dot_claude/ dot_agents/ dot_gitconfig.tmpl ...
```

What each side manages (`chezmoi managed` on that side shows the full list):

| Target | Windows (`%USERPROFILE%`) | WSL (`~`) |
| --- | --- | --- |
| `.gitconfig`, `.config/git/` (ignore, personal include, allowed_signers) | yes | yes |
| `.claude/settings.json` (merged), `.claude/skills/`, `.agents/skills/` | yes | yes |
| `.wezterm.lua`, `.wslconfig`, `AppData/Roaming/topgrade.toml`, `AppData/Local/arkenfox/user.js` | yes | - |
| `.config/fish`, `.config/tmux` (+ tpm), `.config/nvim`, `.config/mise`, `.config/gh`, `.config/topgrade.toml` | - | yes |
| `.local/bin/wsl-open`, `.local/bin/push-ssh-key`, `.profile` | - | yes |
| `.local/bin/agent-sandbox`, `.local/bin/new-worktree`, `.config/herdr` | - | with `features.agentSandbox` |
| `.glzr/glazewm/config.yaml`, `.glzr/glazewm/*.ps1`, `.glzr/glazewm/*.ahk`, `.glzr/zebar/**` | with `features.glazewm` | - |
| scripts | `winget-packages`, `ssh-agent-check`, `keyboard-scancode-map`, `obsidian-vimrc`, `powertoys-keyboard`, `firefox-userjs`, `focus-follows-mouse`, `window-borders`, `glazewm-startup`, `wsl-apply` | `prereqs`, `apt`, `brew`, `mise`, `shell`, `wsl-system`, `claude-code` |

---

## First-time setup

### 1. Windows

From a clone of this repo (on this machine: `C:\Users\37946\repos\dotfiles-windows`),
in Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1
```

`bootstrap.ps1`:

1. checks winget,
2. installs, if missing, Git for Windows (`Git.Git`, machine scope, may show
   UAC), chezmoi (`twpayne.chezmoi`) and PowerShell 7 (`Microsoft.PowerShell`),
3. sets the CurrentUser execution policy to RemoteSigned if scripts can't run,
4. sets `core.autocrlf=false` for this repo,
5. runs `chezmoi init --source <repo> --apply`. It asks for the
   [data values](#configuration-chezmoi-data) once, writes the config with
   `sourceDir` = this repo (so a plain `chezmoi apply` works from then on), and
   runs the Windows scripts (winget packages, ssh-agent check, PowerToys,
   Obsidian),
6. prints the next steps.

Options: `-PromptDefaults` accepts every default without asking; `-NoApply`
only writes the config. Re-running it is safe.

On a fresh machine without git, install it first
(`winget install --id Git.Git -e --scope machine`), then
`git clone https://github.com/jvik/dotfiles-windows $HOME\repos\dotfiles-windows`.

Then:

1. **Bitwarden Desktop**: sign in, then Settings > **Enable SSH agent**. See
   [SSH and Bitwarden](#ssh-keys-and-bitwarden).
2. Open a new terminal, so the PATH changes from the winget installs are picked up.
3. `wsl --shutdown` (wait about 8 seconds) so the new `.wslconfig` takes effect.

### 2. Put the repo on GitHub (once)

The repo starts out local. `chezmoi init` may already have run `git init`
there; the commands below work either way. Do this after the Bitwarden step,
because the managed `.gitconfig` signs commits with your SSH key.

```powershell
cd $HOME\repos\dotfiles-windows
git init
git add -A
git commit -m "Initial commit"
git branch -M main
gh auth login
gh repo create jvik/dotfiles-windows --public --source . --remote origin --push
```

Without `gh`, create the empty repo on github.com and run
`git remote add origin git@github.com:jvik/dotfiles-windows.git`, then
`git push -u origin main`. If signing fails at this point (no agent yet),
commit once with `git -c commit.gpgsign=false commit ...` and fix the agent
afterwards.

### 3. WSL (inside Ubuntu, once)

```bash
bash /mnt/c/Users/<you>/repos/dotfiles-windows/bootstrap-wsl.sh
```

`bootstrap-wsl.sh [extra chezmoi init args]` installs `curl` if missing,
installs chezmoi to `~/.local/bin` (get.chezmoi.io), and runs
`chezmoi init --apply --source <checkout>`, where the checkout is the
directory the script lives in. Extra args go to `chezmoi init`, e.g.
`bootstrap-wsl.sh --promptDefaults`. There is no second clone: WSL's chezmoi
reads the Windows checkout through `/mnt/c`.

The first apply asks for your sudo password and runs, in order: prereqs
(build tools, Homebrew), apt (fish PPA, base packages, Docker Engine), brew,
mise, shell (`chsh` to fish, Fisher plugins, tpm), wsl-system (`/etc/wsl.conf`,
inotify limits) and Claude Code (native installer).

Afterwards, **from Windows**: `wsl --shutdown`, wait about 8 seconds, then
open WezTerm. This is needed once because `/etc/wsl.conf` changed (systemd,
default user, `appendWindowsPath=false`) and so that the new docker group
membership and the fish login shell apply.

Then, in WSL: `gh auth login`, `bw login`, and `claude` (log in). Claude Code
on Windows (winget) is a separate install with its own login.

From then on, apply from Windows only (next section).

### One apply for both sides

`run_after_90-wsl-apply` is the last Windows script. It runs
`chezmoi init --apply --source <checkout>` inside the `wslDistro` distro,
through `wsl.exe` and a login bash (`~/.profile` puts chezmoi and Homebrew on
PATH). So `chezmoi apply`, `chezmoi update` and `chezmoi init --apply` on
Windows bring both sides up to date, including uncommitted edits, with no git
round trip.

* `init` rather than `apply`: WSL's chezmoi config is regenerated from
  `home/.chezmoi.yaml.tmpl` on every run (stored answers are kept), so it never
  goes stale and its `sourceDir` always points at the checkout. A WSL setup that
  still uses an old `~/.local/share/chezmoi` clone moves over on the next
  Windows apply; delete the clone afterwards.
* Like every script, it does not run for `chezmoi apply <target>`,
  `--dry-run` or `--exclude scripts`, so scoped applies stay on Windows.
  `chezmoi diff` on Windows shows only the Windows side; for WSL, run
  `chezmoi diff` in WSL.
* WSL keeps the terminal, so sudo and chezmoi's "changed since chezmoi last
  wrote it" prompts work as in WSL. A failing WSL apply fails the Windows
  apply. With no distro or no chezmoi in WSL (before `bootstrap-wsl.sh`) it
  only prints a hint.
* `chezmoi apply` inside WSL still works and uses the same checkout. Run git
  (and `chezmoi update`) from Windows: git over `/mnt/c` is slow.
* Reading the checkout over 9P adds about a second per WSL apply. File modes
  come from the source names (`executable_`, `private_`), not from NTFS. The
  working tree must stay LF (`.gitattributes`, `.editorconfig`, VS Code's
  `files.eol`), because WSL now reads it before git normalizes anything.

---

## Configuration (chezmoi data)

`chezmoi init` asks for these once (`promptStringOnce`/`promptBoolOnce`) and
stores them in the chezmoi config. To change a value later, run
`chezmoi edit-config`, then `chezmoi apply`. Re-running `chezmoi init` keeps
the stored answers.

| Key | Default | Used for |
| --- | --- | --- |
| `name`, `email` | name from the old gitconfig / `jorgen.vik@kystverket.no` | default (work) git identity |
| `personalEmail` | `mail@jvik.no` | repos under `~/src/personal/` (`includeIf`) |
| `signingKey` | the old SSH public key | SSH commit signing; `""` turns signing off |
| `githubOrg` | `""` | `ghfco` / `ghfuzzyclone` / `krepo` (`$gh_org`) |
| `wslDistro` | `Ubuntu` | WezTerm default domain, topgrade, hints |
| `windowsUser` | detected (`%USERNAME%`, or `cmd.exe` from WSL) | `/mnt/c/Users/<windowsUser>` paths in WSL |
| `obsidianVault` | `""` (skip) | vault folder that gets `.obsidian.vimrc` |
| `features.docker` | `true` | Docker Engine (docker-ce) in WSL |
| `features.agentSandbox` | `true` | herdr, `agent-sandbox`, `new-worktree`, `hr`, the `as*` abbrs (WSL) |
| `features.powertoys` | `true` | PowerToys + Keyboard Manager remaps (Windows) |
| `features.glazewm` | `true` | GlazeWM tiling window manager, started at sign-in, with the Zebar status bar (Windows) |

Only `home/.chezmoi.yaml.tmpl` looks at the OS. It writes `isWindows`, `isWSL`
(linux and a kernel osrelease containing "microsoft") and `isLinux`, and
everything else branches on those.

---

## Adding software

There is one installer per tool, so nothing shadows anything on PATH:

| Where | What | File |
| --- | --- | --- |
| winget | Windows apps and Windows-side CLIs | `home/.chezmoidata/packages.yaml` -> `packages.windows.winget` |
| apt | base OS bits of the distro only | `packages.wsl.apt` |
| Homebrew | general CLIs in WSL | `packages.wsl.brew` |
| mise | version-pinned toolchains/CLIs (kubectl, helm, terraform, node, cplt, wsl2-ssh-agent, herdr, Copilot CLI) | `home/dot_config/mise/config.toml.tmpl` |
| native installer | Claude Code in WSL (updates itself) | `run_once_after_60-claude-code.sh.tmpl` |

* winget entries are `{id, scope (user|machine, optional), note}`. Check the
  exact id with `winget show --id <id> -e` before adding it.
* Feature-gated lists (`packages.windows.powertoys`, `packages.windows.glazewm`,
  `packages.wsl.docker`)
  are installed only when the matching `features.*` flag is true.
* The install scripts render their list into their own text, so after an edit
  the next `chezmoi apply` re-runs **only** the script whose list changed
  (`run_onchange_`). `just packages` runs just the scripts.
* Edit on Windows and `chezmoi apply` there; that applies WSL too.

Removing an entry does not uninstall anything. For brew, remove the formula
from the list and apply with `BREW_BUNDLE_CLEANUP=1 chezmoi update` (fish
accepts that syntax) to uninstall formulae that are no longer listed;
otherwise the brew script just lists them. For mise, `mise prune` removes
versions nothing uses. winget and apt removals are manual.

`run_onchange_after_10-winget-packages` logs failures and carries on (it
prints a retry command per package). chezmoi does not re-run it until the
list changes, so run those commands by hand.

Scripts named `run_after_*` run on **every** apply. They are cheap checks:
the ssh-agent check, the keyboard Scancode Map check, the PowerToys remaps, the Obsidian vimrc copy, the
Firefox user.js, focus follows mouse, the window borders and the GlazeWM
startup entry. The last one, `wsl-apply`, applies the WSL side.

---

## Updates

`topgrade` (`just upgrade`; `sysup` in fish) on both sides. **Running it on
Windows covers both**:

* **Windows** (`%APPDATA%\topgrade.toml`, `only = ["winget", "wsl"]`): winget
  upgrades the Windows apps (topgrade included, via `self_rename`), then the
  `wsl` step runs topgrade inside Ubuntu. `wsl --update` is left out on
  purpose (IT owns the WSL version).
* **WSL** (`~/.config/topgrade.toml`): apt (`system`, prompts for sudo),
  Homebrew, mise, Fisher plugins (`shell`) and tmux plugins.

The Windows `wsl` step finds topgrade with `wsl -d Ubuntu bash -lc "which topgrade"`.
`~/.profile` (WSL only) puts Homebrew on that login PATH; check it with
`wsl -d Ubuntu bash -lc 'which topgrade mise'`.

Claude Code updates itself on both sides. Dotfile changes come from git:
`chezmoi update` (or `git pull` + `chezmoi apply`) on Windows, which applies
WSL too.

---

## SSH keys and Bitwarden

The keys live in Bitwarden (SSH key items). Bitwarden Desktop on Windows
serves them on `\\.\pipe\openssh-ssh-agent`; only one process can own that
pipe.

1. Bitwarden Desktop: sign in, Settings > **Enable SSH agent**. Keep it running
   and unlocked; it can ask for confirmation when a key is used.
2. Disable the Windows **OpenSSH Authentication Agent** service. The
   `run_after_20-ssh-agent-check` script checks this on every apply and prints
   the fix if needed. From an elevated PowerShell:
   `Stop-Service -Name ssh-agent -Force; Set-Service -Name ssh-agent -StartupType Disabled`.
   Then restart Bitwarden.
3. Windows: git uses `C:/Windows/System32/OpenSSH/ssh.exe` (`core.sshCommand`)
   and signs with `C:/Windows/System32/OpenSSH/ssh-keygen.exe`, both through the
   pipe. Test: `ssh-add -l`, `ssh -T git@github.com`.
4. WSL: [`mame/wsl2-ssh-agent`](https://github.com/mame/wsl2-ssh-agent)
   (installed by mise) bridges the pipe to `~/.ssh/wsl2-ssh-agent.sock` through
   PowerShell 7 (`pwsh.exe`, falling back to `powershell.exe`); `wsl.fish` starts
   it and sets `SSH_AUTH_SOCK`. Test the same way in fish. Windows PowerShell 5.1
   starts the relay too slowly for the daemon's 10s limit, which kills the
   daemon (`Couldn't get agent socket?` when signing).
5. Add the public key on GitHub as both an **Authentication** and a **Signing**
   key, so signed commits show as Verified.

Bitwarden CLI: `bw` in WSL comes from brew (`bw-unlock`, `push-ssh-key`, the
sops age key). `Bitwarden.CLI` for Windows is commented out in packages.yaml.

## Git identity

The managed `~/.gitconfig` (both sides) uses the **work** identity (`name`,
`email`). Repos under `~/src/personal/` (`%USERPROFILE%\src\personal\` on
Windows) include `~/.config/git/personal.gitconfig`, which switches the email
to `personalEmail` (`includeIf "gitdir:~/src/personal/"`). Check inside such a
repo with `git config user.email`.

Signing (`gpg.format=ssh`) is on only when `signingKey` is non-empty;
`~/.config/git/allowed_signers` lets `git log --show-signature` verify your
own commits. In WSL, GitHub HTTPS goes through `gh auth git-credential`, and
Azure DevOps through Git Credential Manager from Git for Windows (probed at
apply time under `C:\Program Files\Git` and the user-scope
`%LOCALAPPDATA%\Programs\Git`; run `chezmoi apply` in WSL again if Git for
Windows is installed or moved later).

---

## Clipboard and opening files (WSL)

* **Clipboard**: `win32yank.exe` (winget `equalsraf.win32yank`, reached through
  the WinGet Links dir that `wsl.fish` puts on PATH).
  * nvim: `vim.g.clipboard` uses win32yank when it is executable, else OSC 52
    (copy only; paste with the terminal's paste key).
  * tmux: `set-clipboard on` (OSC 52 to WezTerm), and copy-mode `y` also pipes
    to win32yank (fallback `clip.exe`).
  * fish: `copy [file]` (win32yank, fallback `clip.exe` fed UTF-16LE so
    Norwegian letters survive) and `pasta` (win32yank, fallback
    `powershell.exe Get-Clipboard`).
* **Opening URLs/files**: `~/.local/bin/wsl-open` (`$BROWSER`, the `open`
  alias, `gh browse`, login flows). URLs go to `powershell.exe Start-Process`,
  paths to `explorer.exe` with `wslpath -w`. wslu/wslview is not used
  (discontinued).
* **Windows PATH**: `/etc/wsl.conf` sets `appendWindowsPath=false`. `wsl.fish`
  adds back only System32, Windows, WindowsPowerShell, OpenSSH, WinGet Links and
  the VS Code `bin` dirs, after the Linux paths. In bash, call Windows tools by
  full path.

---

## Claude Code settings

`~/.claude/settings.json` is **merged**, not owned, on both sides
(`%USERPROFILE%\.claude` for the native Windows install, `~/.claude` in WSL;
they never share settings). `home/dot_claude/modify_settings.json` is a
chezmoi modify-template: it fills in defaults from
`home/.chezmoitemplates/claude-settings.common.json` plus the OS overlay
(`claude-settings.windows.json` / `claude-settings.linux.json`, picked by
`isWindows`). The overlay's `permissions.allow`/`deny` are appended to the
common ones.

* Existing local values win recursively, including `false`, `null` and empty
  values. Arrays in the file replace the defaults as a whole, so a new default
  rule never reaches a machine that already has that array. If nothing is
  missing, the file is left byte for byte unchanged.
* To adopt a changed default, delete that key from `~/.claude/settings.json`
  and run `chezmoi apply ~/.claude/settings.json`.
* Never `chezmoi re-add` this file; edit the defaults files to share a setting.
* `.claude/settings.local.json` in a project is for that project only.

Windows overlay: PowerShell tool rules (read-only git/chezmoi allows; chaining
`;`, `&&`, `||` and `$(...)` denied; pipelines and `&` ask), Read denies for
keys and credential stores. No sandbox (unsupported on native Windows).

WSL overlay: the Claude Code Bash **sandbox is on**, with
`autoAllowBashIfSandboxed` off. Without Claude Code's optional seccomp filter,
sandboxed commands can still open Unix sockets: the WSL interop socket (starts
Windows programs outside the sandbox), the docker socket and the ssh-agent
socket. So the sandbox is defence in depth, not a replacement for the
permission prompt. Only turn auto-allow on (in `~/.claude/settings.json`) after
`/sandbox` shows the seccomp filter installed **and** `cmd.exe /c ver` fails
inside the sandbox. Sandboxed commands cannot read `/mnt` (except `/mnt/wsl`),
so Windows tools such as `clip.exe` fail there and keep WSL projects on ext4.

### Personal agent skills

Shared skills live in `home/.chezmoitemplates/skills/<name>/SKILL.md` and are
deployed twice: to `~/.agents/skills/` (Codex and other agents) and to
`~/.claude/skills/` (Claude Code), on both sides. `git-worktrees` covers
isolated checkouts, shared Git metadata, validation and cleanup. Edit the
template, then `chezmoi apply ~/.agents/skills ~/.claude/skills`. The
directories are not exact, so separately installed skills coexist.

---

## Agent sandbox and herdr (WSL, `features.agentSandbox`)

### agent-sandbox

`agent-sandbox` (`home/dot_local/bin/executable_agent-sandbox`) runs a coding
agent inside [bubblewrap](https://github.com/containers/bubblewrap), so
`--dangerously-skip-permissions` / `--allow-all-tools` can only damage the
current project:

```fish
agent-sandbox claude --dangerously-skip-permissions
agent-sandbox --gh copilot --allow-all-tools
agent-sandbox codex
```

The fish abbreviations `asclaude`/`asc`, `ascopilot`/`asco` and `ascodex`
expand to these. Starting an agent directly still bypasses the sandbox.

* **Read-write:** the git toplevel (or `$PWD`), the main `.git` of a linked
  worktree, and the agent's state (`~/.claude`, `~/.copilot`, `~/.codex` or
  `$CODEX_HOME`).
* **Read-only inside, because the host runs them later:**
  `~/.claude/settings.json` and its `hooks/`, `commands/`, `agents/`, `skills/`
  and `plugins/` dirs, plus the repo's `.git/hooks` and `.git/config`.
  `~/.claude.json` (user MCP servers) is a throwaway copy. Side effect: commands
  that write the repo config (`git remote add`, `--set-upstream-to`) must run
  outside. Anything else the agent writes in the project (Makefile, package.json
  scripts, `mise.toml`, `.envrc`, ...) is still yours to review.
* **Read-only:** `/usr`, `/etc`, `/opt`, linuxbrew, mise/cargo/go/bun
  toolchains, git config, `~/.local/bin`.
* **Hidden:** the rest of `$HOME` (an empty tmpfs, discarded on exit) and `/run`
  (no systemd bus, ssh-agent bridge or docker socket). The environment is
  cleared down to an allowlist.
* Network is shared. Commits are unsigned unless `--ssh` exposes the
  wsl2-ssh-agent socket. `--gh` passes `gh auth token` as `GH_TOKEN`; Copilot
  gets `COPILOT_GITHUB_TOKEN` the same way. `--ro`/`--rw <path>` add binds,
  e.g. `--ro ~/.agents/skills`.
* Refuses to run with `$HOME`, `/`, or anything on `/mnt` as the project.
  Claude's auto-updater is disabled inside; update from outside.
* Claude's own Bash sandbox (also bwrap) is turned off inside; this outer
  layer already isolates it, and nesting is untested.
* Codex runs with `--no-daemon`, so it cannot reuse a host-side daemon.
  Codex is **not installed** by default; uncomment `npm:@openai/codex` in
  `home/dot_config/mise/config.toml.tmpl` if policy allows it.

**WSL invariant**: `/mnt`, `/run/WSL` and `WSL_INTEROP` stay out of the
sandbox. WSL starts a Windows `.exe` by handing it to the host through the
interop socket; a reachable socket would let the agent run
`powershell.exe`/`cmd.exe` with your full Windows rights, and `/mnt/c` is
your whole Windows profile. Only `/run/systemd/resolve` and the single
`/mnt/wsl/resolv.conf` file (DNS) are bound, `--clearenv` drops the WSL
variables, and `--ro`/`--rw` refuse `/mnt`, `/run` and `/init`. After changing
the script, run from a project:

```bash
agent-sandbox bash -c 'ls /mnt /run; echo "$WSL_INTEROP"; cmd.exe /c ver'
```

It must list nothing, print an empty line, and fail to start `cmd.exe`.

VS Code's agent terminal sandbox (org policy) runs on the WSL side under
Remote-WSL and needs unprivileged user and network namespaces. The apt list
has `bubblewrap`, `slirp4netns`, `uidmap` and `iptables`; the WSL kernel does
not enforce Ubuntu's AppArmor userns restriction, so the old AppArmor profile
is gone. Check with `unshare --user --net true`.

### herdr

[herdr](https://herdr.dev) (`home/dot_config/herdr/config.toml`, installed by
mise) is the agent multiplexer. The prefix is `ctrl+a` as in tmux, so don't nest
them. `prefix+a` / `prefix+shift+a` open sandboxed Claude / Copilot in a new
pane, `prefix+alt+g` opens lazygit, `prefix+w` runs `new-worktree`. Toasts are
in-app (`delivery = "herdr"`): WSL has no notification daemon.

Start it with `hr` instead of `herdr`: herdr keeps a background server, so
plain `herdr` reattaches to old workspaces (often `~`, where the sandbox
refuses to run); `hr` first adds a workspace for the current directory.
Session restore is off and `herdr integration install` should not be run:
both would relaunch agents outside the sandbox. Update herdr through mise
(topgrade), not `herdr update`.

`new-worktree [--from REF] [--agent claude|copilot] <branch>` creates a git
worktree as its own herdr workspace (new branches start from a fetched
`origin/main`) and runs `agent-sandbox claude` in it. It must run from a normal
herdr pane, not from inside the sandbox, which hides the herdr socket. Keep
repositories and worktrees in the WSL home (e.g. `~/src`), not on `/mnt/c`.

---

## Keyboard layout

The old sway `xkb_options "caps:swapescape,altwin:swap_lalt_lwin"`, Caps Lock
<-> Esc and Left Alt <-> Left Win, is a Windows Scancode Map
(`HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout`, value
`Scancode Map`). The keyboard driver applies it before any program sees a key,
so PowerToys shortcuts and GlazeWM keybindings all see the physical Left Alt
key as Win. (As a PowerToys key remap it was done in a keyboard hook, and
GlazeWM did not see the swapped Win key.) It is machine-wide, for all users and
keyboards.

Writing it needs admin and a restart, so `run_after_35-keyboard-scancode-map`
only checks it on every apply and, when it differs, prints the elevated
command that sets it. Run that command, then restart Windows.

## PowerToys remaps (`features.powertoys`)

The Keyboard Manager remaps are managed from this repo:
`home/.chezmoidata/powertoys.yaml` (`powertoys.keyboardManager`) lists them in
PowerToys' own file format (key remaps, shortcut remaps, app-specific and
to-text remaps). It holds sway-style shortcuts with mod = Win (the physical
Left Alt key, see [Keyboard layout](#keyboard-layout)): `mod+Shift+Q` closes the window (Alt+F4), `mod+D`
opens the Command Palette (sends its Win+Alt+Space hotkey), `mod+Shift+F`
starts a new Firefox window and `mod+Enter` a new WezTerm window.

On every apply `run_after_40-powertoys-keyboard` writes those sections into
`%LOCALAPPDATA%\Microsoft\PowerToys\Keyboard Manager\default.json` (the active
profile) when they differ, creating the file if PowerToys has not yet, and
tells a running Keyboard Manager to reload. Other fields in the file are kept.
The repo wins: remaps made in the PowerToys editor are replaced on the next
apply (the previous file is kept as `default.json.chezmoi.bak`), so to keep
one, copy its entry from the file into `powertoys.yaml`.

The script only reads PowerToys' `settings.json` and warns when Keyboard
Manager is disabled or PowerToys does not run at startup (the remaps only work
while PowerToys runs); turn those on in PowerToys Settings.

## Focus follows mouse

As in sway, a window gets keyboard focus as soon as the pointer is on it
(no delay), without being raised. `run_after_60-focus-follows-mouse` sets this on
every apply when it differs (it is Control Panel's "Activate a window by
hovering over it with the mouse" plus the no-raise and delay options); to
change it, edit the `$desired*` values at the top of the script.

## No network in standby on battery

So a sleeping laptop in a bag does not keep waking on Wi-Fi traffic,
`run_after_65-standby-network` sets the active power plan's "Networking
connectivity in Standby" to Disable on battery (Modern Standby / S0). On AC it
is left alone. When powercfg cannot write it, the script prints the command
for an elevated PowerShell; when a group policy sets it, the script only
warns.

`run_after_66-wake-devices` also turns off "Allow this device to wake the
computer" for the devices matching `$noWakePatterns` at the top of the script
(default `*Bluetooth*`; `powercfg /devicequery wake_armed` lists the
candidates). Windows arms wake per piece of hardware, so Bluetooth headphones
are stopped by disarming the Bluetooth adapter, which stops every Bluetooth
device. Disarming needs admin: when it fails, the script prints the elevated
commands.

## Window borders

To show which window is active, as sway's focused border does,
`run_after_70-window-borders` turns on Settings > Personalization > Colors >
"Show accent color on title bars and window borders" on every apply. The active
window gets an accent-colored title bar and 1px border, inactive ones stay grey.
The color is the Windows accent color, set in the same Settings page. While
GlazeWM runs, its border colors replace the accent color on the border.

## GlazeWM (`features.glazewm`)

[GlazeWM](https://github.com/glzr-io/glazewm) tiles windows the way sway did.
`home/dot_glzr/glazewm/config.yaml` (target `~/.glzr/glazewm/config.yaml`) is
ported from the old sway config. mod is `lwin`, which is the physical Left Alt
key because of the Scancode Map ([Keyboard layout](#keyboard-layout)): `mod` + hjkl/arrows moves focus and
`mod+Shift` + hjkl/arrows moves the window, `mod+1..0` switch workspace and `mod+Shift+1..0` move the
window there, `mod+Tab` goes to the previous workspace, `mod+r` enters resize
mode, `mod+e` toggles the split direction, `mod+f` fullscreen,
`mod+Shift+space` floating, `mod+Shift+e` exits and `mod+Ctrl+Shift+c`
reloads the config. The focused window gets sway's gruvbox yellow border.

* `mod+l` cannot move focus right: Windows locks the screen on Win+L before any
  program sees it. Use `mod+Right` (and `mod+Shift+Right` to move).
* `mod+Enter`, `mod+Shift+f`, `mod+Shift+q` and `mod+d` stay PowerToys remaps,
  and focus follows mouse stays the Windows setting, so they keep working while
  GlazeWM is paused (`mod+Shift+p`) or not running.
* sway's tabbed/stacking layouts, sticky windows and scratchpad have no
  GlazeWM equivalent.
* Teams and Slack live on workspace 4 (a window rule). `mod+Shift+t` (Teams)
  and `mod+Shift+s` (Slack) run `summon-app.ps1`, which fetches the app to the
  current workspace and focuses it; pressing again sends it back to 4. If the
  app has no window (not running or in the tray) it is opened first. Errors go
  to `%TEMP%\glazewm-summon-app.log`.
* Workspace 10 (`mod+0`) stays on the laptop's built-in display.
  `bind_to_monitor` only takes a position-based index, so
  `pin-laptop-workspace.ps1` (a GlazeWM startup command) finds the built-in
  display through WMI and moves the workspace there whenever it is activated
  or the monitors change. Errors go to `%TEMP%\glazewm-pin-laptop-workspace.log`.
* Tapping mod alone does not open the Start menu (`Ctrl+Esc` still does).
  GlazeWM only prevents that after its own keybindings, so
  `suppress-start-menu.ahk` sends an unassigned key on every Win press. It
  passes Win through.
* Bitwarden Desktop and the Firefox extension's pop-out window are floating and
  sticky: a window rule ignores them, so they stay visible on every workspace,
  and `bitwarden-on-top.ahk` keeps them always on top. It also centres each new
  pop-out at a sensible size.
* Greenshot's dialogs ("Save image?", Save As) are owned by its editor window,
  which GlazeWM's window rules do not reach, so `greenshot-dialogs-on-top.ahk`
  keeps them always on top.
* New Outlook's reminders window is floating and sticky the same way as
  Bitwarden: a window rule ignores it and `outlook-reminders-on-top.ahk` keeps
  it always on top. It shares process and class with the main window, so both
  match it by title ("Påminnelser – …" or "Reminders – …"); for another UI
  language, add its word to both.
* `Alt+Space` (the physical Win+Space) toggles M365 Copilot Chat as a floating
  drop-down (`copilot-chat.ahk`). It is an Edge app window
  (`msedge --app=https://m365.cloud.microsoft/chat`, work account) that a
  window rule ignores, so it floats on every workspace. The hotkey opens it if
  needed, shows it centred on the monitor under the mouse, always on top, and
  hides it again when pressed while it has focus. It takes over Alt+Space from
  the window menu. If the window ever tiles instead, its title does not match
  `COPILOT_TITLE` (keep it in sync with the rule in `config.yaml`).
* The AutoHotkey (v2) helpers run as one process with one tray icon:
  `helpers.ahk` `#Include`s each of them. GlazeWM starts it on startup and on a
  config reload, and it exits when GlazeWM does. A new helper is one more
  `#Include` line.
* Reload the config (`mod+Ctrl+Shift+c`) rather than restarting GlazeWM: a
  reload keeps everything. GlazeWM itself forgets on a restart which workspace
  each window was on, so `remember-workspaces.ps1` (a GlazeWM startup command)
  records it by window handle in
  `%LOCALAPPDATA%\glazewm-window-workspaces.json` and moves the windows back
  when GlazeWM starts. Only the workspace comes back, not the split layout.
  Errors go to `%TEMP%\glazewm-remember-workspaces.log`.
* An app opens on the workspace it was started from, even if you switch
  workspace while it loads (GlazeWM itself uses whichever workspace is focused
  when the window appears). `open-on-launch-workspace.ps1` (a GlazeWM startup
  command) records the focused workspace over time and moves a new window to
  the one that was focused when its process started. It only acts on processes
  started in the last 20 s, so a new window of an app that was already running
  (a second Firefox window) still opens where you are, and it leaves windows
  that a window rule placed (Teams, Slack), elevated apps and UWP apps alone.
  Errors go to `%TEMP%\glazewm-open-on-launch-workspace.log`.

### Zebar status bar

[Zebar](https://github.com/glzr-io/zebar) replaces waybar: GlazeWM starts it
(`startup_commands`) and kills it on exit, and a window rule keeps GlazeWM from
tiling it. `home/dot_glzr/zebar/` holds `settings.json` (which widget starts)
and the `topbar` widget pack: one bar per monitor, docked to the top edge so
windows tile below it. Left: that monitor's workspaces (click to focus; the
focused one is underlined in yellow), the binding mode, PAUSED, and on the
focused monitor the tiling direction. Right: the current media session (click
plays/pauses), keyboard layout, volume (click mutes, scroll changes it),
network, download/upload rate, CPU, memory, C: usage, battery, the weather
(located from the public IP) and the date with week number and time. Colors are the gruvbox palette of the window borders. The widget is plain
HTML/JS (`bar.html`, `styles.css`) that loads the zebar client and the icon
font from a CDN; Zebar caches them for a week. Zebar rewrites `settings.json`
when widgets are toggled from its tray icon; the next apply restores it.

The winget packages are installed with the other feature-gated lists, and
`run_after_80-glazewm-startup` adds GlazeWM to the per-user startup list
(`HKCU\Software\Microsoft\Windows\CurrentVersion\Run`), or removes it when the
feature is off. After a `chezmoi apply` that changes the config, reload it with
`mod+Ctrl+Shift+c`.

## Obsidian

Set `obsidianVault` to the vault folder (`chezmoi edit-config`). Every apply
then copies `home/.chezmoitemplates/obsidian.vimrc` to `<vault>\.obsidian.vimrc`
when it differs (backup `.bak`). It is read by the "Vimrc Support" community
plugin with Settings > Editor > Vim key bindings on.

## Firefox (arkenfox)

Firefox itself is installed by IT. The repo manages only `user.js` in the
default profile, which needs no admin rights and no enterprise policies:
chezmoi downloads arkenfox `user.js` pinned to a release commit (with a
sha256 check, `.chezmoiexternal.toml.tmpl`) to
`%LOCALAPPDATA%\arkenfox\user.js`, and on every apply
`run_after_50-firefox-userjs` appends
`home/.chezmoitemplates/firefox-user-overrides.js` and writes the result to
the `Default=` profile of each `[Install...]` section in
`%APPDATA%\Mozilla\Firefox\profiles.ini` when it differs (backup
`user.js.chezmoi.bak`). Firefox applies it on its next start. Settings made in
the Firefox UI that user.js also sets are reset on every start, so change the
overrides file instead.

The overrides also carry the pref equivalents of the Linux repo's
`policies.json` (Firefox Home without widgets/stories, no default-browser
check, no onboarding). Policy-only parts are done once by hand: install
uBlock Origin and Bitwarden from addons.mozilla.org (Firefox Sync brings them
to the next machine), restore the uBlock settings from a backup, and add the
search engine in Settings > Search. IT's policies (`about:policies`) win over
user.js.

A pref removed from the overrides stays in the profile's `prefs.js`: close
Firefox and run arkenfox's `prefsCleaner.bat` in the profile folder. To move
to a newer arkenfox release, change the commit and checksum in
`.chezmoiexternal.toml.tmpl` together. arkenfox clears cookies when Firefox
closes; allow the sites to keep under Settings > Privacy & Security > Cookies
and Site Data > Manage Exceptions, or set the override that is commented out
in the overrides file.

## Docker (WSL, `features.docker`)

Docker Engine (docker-ce, buildx and compose plugins) from Docker's own apt
repository, inside WSL, with systemd starting `docker.service`. No Docker
Desktop: don't install it, its WSL integration would conflict. The apt script
removes conflicting distro packages (`docker.io`, `podman-docker`, ...) and
adds you to the `docker` group; after `wsl --shutdown`, check with
`docker run --rm hello-world`. `ctop` (brew) is the TUI. With mirrored
networking, published ports are reachable from Windows on `localhost`.

## Corporate TLS inspection (optional)

If the network re-signs TLS, export the root CA(s) as Base-64 PEM and save
them as `~/.config/certs/*.crt` **inside WSL** (not in this repo; `*.crt` is
git-ignored). The WSL scripts copy them to `/usr/local/share/ca-certificates`
and run `update-ca-certificates` (the prereqs script before Homebrew, the apt
script on every cert change, since it embeds each cert's hash), and fish then
exports `NODE_EXTRA_CA_CERTS`, `REQUESTS_CA_BUNDLE`, `SSL_CERT_FILE`,
`CURL_CA_BUNDLE` and `PIP_CERT` pointing at the system bundle. Nothing happens
while the folder is empty. Check the CA fingerprint with IT first. On
Windows most tools use the Windows certificate store; Git for Windows only does
with `http.sslBackend=schannel`.

---

## Troubleshooting

**No network in WSL on the VPN.** Mirrored networking (`.wslconfig`) is the
most VPN-friendly mode, but some clients (Zscaler, GlobalProtect, Cisco Secure
Client) break it. Edit `home/dot_wslconfig.tmpl`: replace
`networkingMode=mirrored` with the commented `networkingMode=nat` (keep
`dnsTunneling=true`), `chezmoi apply`, `wsl --shutdown`. IT can lock
`.wslconfig` keys through policy; `wsl --version` and the WSL Settings app show
what is in effect.

**Execution policy.** `Get-ExecutionPolicy -List`. This machine has a
RemoteSigned `MachinePolicy` (GPO), which beats `-ExecutionPolicy Bypass` on the
command line. Local scripts (bootstrap.ps1 in a git clone, and the temp scripts
chezmoi writes) still run. A repo downloaded as a ZIP carries the
Mark of the Web: `Get-ChildItem -Recurse | Unblock-File`. If IT ever enforces
AllSigned or Constrained Language Mode, the `.ps1` scripts cannot run; ask IT.

**CRLF.** Symptoms in WSL: `$'\r': command not found` or `bash\r: No such file`.
`.gitattributes` forces LF (`* text=auto eol=lf`) and bootstrap.ps1 sets
`core.autocrlf=false`. Check with `git ls-files --eol` (look for `crlf`), fix
with `git add --renormalize .` and commit. Keep `.ps1` files pure ASCII
(Windows PowerShell 5.1 reads BOM-less files as ANSI).

**SSH agent.** `ssh-add -l` on Windows shows nothing: Bitwarden is locked, its
SSH agent is off, or the Windows `ssh-agent` service still owns the pipe (see
the apply output). In WSL: check `echo $SSH_AUTH_SOCK` and `command -v wsl2-ssh-agent`
(installed by mise); `pkill wsl2-ssh-agent` and open a new shell to restart the
bridge.

**topgrade on Windows skips WSL.** `wsl -d Ubuntu bash -lc 'which topgrade mise'`
must find both (via `~/.profile`).

**`chezmoi: warning: config file template has changed`.** Run `chezmoi init`
on Windows (stored answers are kept) to regenerate the config. The WSL config
is regenerated by every full Windows apply.

**The Windows apply skips WSL** (`[wsl-apply] ... skipping`): the `wslDistro`
distro is missing, or WSL has no chezmoi yet (run `bootstrap-wsl.sh`). Check
with `wsl -d Ubuntu bash -lc 'command -v chezmoi'`.

**A winget install failed.** The script printed a retry command; run it.
chezmoi re-runs the script only when the package list changes.

---

## Day-to-day

```text
just              # list recipes
just diff         # chezmoi diff
just check        # chezmoi apply --dry-run --verbose
just apply <source-path>   # apply one source file (target path is looked up)
just apply-all    # chezmoi apply --verbose
just update       # chezmoi update (git pull + apply)
just packages     # run only the scripts (installs changed package lists)
just upgrade      # topgrade
just data         # template data this side sees
```

`just` comes from winget on Windows (recipes run in Windows PowerShell) and
brew in WSL; run it in the checkout on either side. On Windows, `apply-all`,
`update` and `packages` also apply WSL; the other recipes act on the side
they run on.

The shell is fish; see [home/dot_config/fish/README.md](home/dot_config/fish/README.md).
`ab` fuzzy-finds every abbreviation, alias and function. Neovim is LazyVim
(`home/dot_config/nvim/`); update plugins with `nvim +Lazy sync +qall`.

---

## What was dropped from the Linux repo

* Ansible bootstrap (roles, galaxy collections, lint venv, per-role hash state):
  replaced by chezmoi `run_onchange_` scripts and `packages.yaml`.
* The sway/Wayland desktop: sway, waybar, swaync, swaylock, kanshi, fuzzel,
  wofi, darkman, GTK/cursor themes, wallpapers, screenshots (satty/wayfreeze),
  networkmanager-dmenu, copyq, systemd user units, udev/logind rules.
* Hardware fixes: Thunderbolt dock reset, a2dp toggle, webcam (cameractrls),
  battery checks, printers, the ROCm Ollama compose setup.
* Flatpaks, mimeapps, teams-for-linux, VS Code `argv.json` files.
* Personal apps on the work machine: Signal, VLC, Plexamp, Vesktop, Mullvad,
  Jotta, LibreOffice, Ollama.
* Firefox enterprise policies (`policies.json`, needs admin and is ignored
  when IT sets policies) and the fixed `main` profile in `profiles.ini`.
  arkenfox and the overrides are kept, see [Firefox](#firefox-arkenfox).
* `vuln-scan` (documented in the old readme, never in the repo).

---

## License

This repository (dotfiles and original configuration content) is released
under the Apache License 2.0. See `home/dot_config/nvim/LICENSE` for the
license text. Third-party tools, plugins, and fonts retain their respective
licenses.
