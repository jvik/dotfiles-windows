# AGENTS.md

Practical guidance for AI agents and other automated contributors in this repository.

## Purpose

This repository is a **chezmoi-based dotfiles setup** for a Windows 11 + WSL2
Ubuntu work machine. The same source is applied **twice**: by `chezmoi.exe` on
Windows (target `%USERPROFILE%`, source = this checkout) and by `chezmoi`
inside WSL (target `~`, source = a git clone in `~/.local/share/chezmoi` on
ext4). The goal is safe, minimal, and idempotent changes.

## Core principles

1. **Keep changes minimal**
   - Make small, focused patches.
   - Do not restructure files or move things unless required.
2. **Fix root causes**
   - When something is broken, correct the source of the issue instead of layering workarounds.
3. **Preserve style**
   - Follow existing patterns in YAML, shell, PowerShell, Lua, and config files.
   - Avoid introducing new tools/frameworks without clear need.
4. **Prioritize idempotency**
   - Install scripts must remain safe to run repeatedly.
5. **Write code for humans first**
   - Prefer clear over clever: descriptive names, small single-purpose functions,
     and named constants instead of magic numbers or raw escape codes.
   - Comments explain *why* (a non-obvious constraint or workaround), not *what*
     the next line does.
   - A reader unfamiliar with the file should be able to follow it top to bottom.

## Repository-specific rules

### Layout

- `.chezmoiroot` contains `home`: the source state is `home/`. Repo-only files
  (README.md, AGENTS.md, CLAUDE.md, justfile, bootstrap.ps1, bootstrap-wsl.sh,
  .gitattributes, .github, .vscode) live at the root and are never deployed, so
  they need no `.chezmoiignore` entry.
- Scripts: `home/.chezmoiscripts/windows/*.ps1.tmpl` and
  `home/.chezmoiscripts/linux/*.sh.tmpl`, numbered in run order.
- Windows-only targets: `home/AppData/...`, `dot_wslconfig.tmpl`,
  `dot_wezterm.lua.tmpl`. WSL-only targets: `dot_config/**` (except
  `dot_config/git`), `dot_local/**`, `dot_profile`. Shared: `dot_gitconfig.tmpl`,
  `dot_config/git/`, `dot_claude/`, `dot_agents/`.

### OS conditionals

- **Only** `home/.chezmoi.yaml.tmpl` may look at `.chezmoi.os` /
  `.chezmoi.kernel`. It writes the data `isWindows`, `isWSL`, `isLinux` (plus
  the other data keys documented in README.md). Every other template,
  `.chezmoiignore`, `.chezmoiexternal.toml.tmpl` and script branches on
  `.isWindows` / `.isWSL` / `.features.*`. This is what makes the WSL variant
  testable from Windows with a hand-written config.
- `home/.chezmoiignore` skips Windows-only targets (`AppData`, `.wslconfig`,
  `.wezterm.lua`, `.chezmoiscripts/windows/**`) unless `isWindows`, and
  WSL-only targets (`.config/**` except `.config/git`, `.local/**`, `.profile`,
  `.chezmoiscripts/linux/**`) unless `isWSL`. Plain (non-template) files that
  belong to a feature are gated there too (e.g. `features.agentSandbox`).
- Script bodies are also wrapped in `{{ if .isWindows }}` / `{{ if .isWSL }}`
  (and the feature flag where relevant), so they render empty and chezmoi
  skips them elsewhere. Keep both guards.
- A new data key needs a `promptStringOnce`/`promptBoolOnce` with a default in
  `home/.chezmoi.yaml.tmpl` (so `chezmoi init --promptDefaults` keeps working),
  a row in the README data table, and the key in the hand-written test configs.
- No `symlink_` entries for Windows targets (they need Developer Mode).

### PowerToys Keyboard Manager

- Remaps live in `home/.chezmoidata/powertoys.yaml` in PowerToys' own JSON
  shape (key codes as quoted decimal strings, every list present). The repo is
  the source of truth: `run_after_40-powertoys-keyboard` replaces only the four
  remap sections of the active profile file and keeps other fields. PowerToys'
  `settings.json` files are runner-owned: read them, never write them.
- Single-key swaps (Caps Lock <-> Esc, Left Alt <-> Left Win) are NOT
  PowerToys remaps but the `Scancode Map` checked by
  `run_after_35-keyboard-scancode-map`, so other keyboard hooks (GlazeWM) see
  the swapped keys. Keep `remapKeys.inProcess` free of them, or they swap back.

### Firefox

- Only `user.js` in the default profile is managed: arkenfox (a pinned
  `.chezmoiexternal` file with a sha256 checksum; change commit and checksum
  together) plus `home/.chezmoitemplates/firefox-user-overrides.js`, written by
  `run_after_50-firefox-userjs`. No enterprise policies (`policies.json`,
  `HKLM\Software\Policies`): they need admin, and IT's policies would make
  Firefox ignore them. Never rewrite `profiles.ini`.

### Packages: one owner per tool

Never install the same tool from two places (PATH shadowing).

- `home/.chezmoidata/packages.yaml`:
  - `packages.windows.winget`: Windows apps and Windows-side CLIs
    (`{id, scope, note}`; verify ids with `winget show --id <id> -e`).
  - `packages.wsl.apt`: base OS bits of the distro only.
  - `packages.wsl.brew`: general CLIs in WSL.
  - Feature-gated lists are keyed by the feature name
    (`packages.windows.powertoys`, `packages.wsl.docker`) and installed only when
    `.features.<name>` is true.
  - The file is plain YAML (no template syntax).
- `home/dot_config/mise/config.toml.tmpl`: version-pinned toolchains/CLIs
  (kubectl, helm, terraform, node, cplt, wsl2-ssh-agent, herdr, npm-backend
  agent CLIs).
- Claude Code: winget on Windows, native installer in WSL (run_once script).
- Updates belong to `topgrade` on each side (scoped by its `only` list), not to
  the install scripts. The Windows run also runs topgrade inside WSL.

### Scripts

- `run_onchange_` for installers driven by a list: render the list into the
  script text (or embed `# hash: {{ include "<path relative to home/>" | sha256sum }}`
  for a non-template input file), so chezmoi re-runs it only when the input
  changes. `run_once_` for one-time installers. `run_after_` only for cheap,
  idempotent checks, since they run on every apply.
- A failing package install logs and continues where possible (winget); a
  missing prerequisite fails loudly.
- **PowerShell (`.ps1`, `bootstrap.ps1`)**: pure ASCII (Windows PowerShell 5.1
  reads BOM-less files as ANSI) and 5.1 compatible: no `&&`, `||`, `??`, `?.`,
  ternary, `-AsHashtable`. chezmoi runs `.ps1` with pwsh if installed, else
  powershell.exe. Embed data that may be non-ASCII base64-encoded (see the
  Obsidian script). Check `$LASTEXITCODE` after native commands; never elevate
  silently, print the elevated command instead.
- **Bash**: `#!/usr/bin/env bash`, `set -euo pipefail`, idempotent, safe to
  re-run, log what they do, `sudo` where needed (interactive prompts are fine),
  no `ping` connectivity gates.
- Do not remove `executable_` prefixes or rename scripts without a clear reason
  (a rename of a `run_once_`/`run_onchange_` script makes it run again).

### Shells

- **Interactive shell in WSL is fish.** Commands suggested for the WSL
  terminal must be fish syntax (`set VAR val`, `(command)` substitution, no
  `[[ ]]` or `export VAR=val`).
- **Windows side is PowerShell.** Commands suggested for Windows must work in
  Windows PowerShell 5.1 unless pwsh is stated.
- `/etc/wsl.conf` has `appendWindowsPath=false`; WSL scripts call Windows
  binaries by absolute path (`/mnt/c/Windows/...`), fish adds a fixed set back.
- Match the shell style already used in each file.

### Chezmoi

- Edit **source files in this repo**, not generated target files in the home dir.
- Respect chezmoi naming conventions (`dot_`, `private_`, `executable_`,
  `modify_`, `.tmpl`).
- For templates, keep compatibility with current variables and defaults.
- `chezmoi apply`/`chezmoi diff` take the **target path**, never the source path
  in this repo. Convert with `chezmoi target-path <source-path>` (`just apply
  <source-path>` does that), or apply the target path directly.
- Prefer applying a **scoped target path** over a bare `chezmoi apply`: a bare
  apply re-applies every managed file and runs scripts, which can revert
  unrelated in-progress edits.
- Each side drives its own chezmoi. WSL reads its ext4 clone, never a checkout
  on `/mnt/c` (the config template refuses that). Changes made on Windows reach
  WSL through git (commit/push, then `chezmoi update` in WSL).

### modify_ files (Claude settings)

- Claude's global settings use `home/dot_claude/modify_settings.json` to merge
  defaults from `home/.chezmoitemplates/claude-settings.common.json` plus the OS
  overlay (`claude-settings.windows.json` / `claude-settings.linux.json`) into
  `~/.claude/settings.json` on each side. The overlay's `permissions.allow` /
  `deny` are appended to the common lists.
- Existing local values win, including arrays; do not replace this with a fully
  managed settings file or use `chezmoi re-add` on it. Change shared defaults
  in the defaults files; they only fill missing keys on existing machines.
- A modify template must be idempotent and pass `.chezmoi.stdin` through
  byte for byte when nothing changes, so the target is not rewritten on every
  apply.
- The WSL overlay keeps `sandbox.autoAllowBashIfSandboxed` false; see README.

### Personal agent skills

- Keep reusable personal workflows in
  `home/.chezmoitemplates/skills/<name>/SKILL.md`. A new skill needs both thin
  wrappers, `home/dot_agents/skills/<name>/SKILL.md.tmpl` and
  `home/dot_claude/skills/<name>/SKILL.md.tmpl`. Keep project-specific
  instructions in the project's `AGENTS.md`.
- Keep skill directories non-exact so independently installed skills can coexist.
- Sandbox users must expose the skill directory (and any symlink targets) read-only.

### Agent sandbox (`home/dot_local/bin/executable_agent-sandbox`, WSL)

- Keep its INVARIANT: `/mnt`, `/run/WSL` and `WSL_INTEROP` stay out of the
  sandbox (a reachable interop socket runs Windows programs with full user
  rights). Files the host later executes (Claude settings/hooks/commands/
  agents/skills/plugins, `.git/hooks`, `.git/config`) stay read-only inside.
- Never test it by running it as part of an automated change; run the quick
  check in its header by hand after changes.

### Documentation (`README.md`, `AGENTS.md`)

- Keep [README.md](README.md) up to date when making significant changes to the
  repository structure or configuration.
- Document new features, data variables, packages lists or configuration
  sections in the README.
- Maintain accuracy of any setup or usage instructions; every path and command
  in the docs must exist.
- Update [AGENTS.md](AGENTS.md) when core functionality changes: new repository
  conventions, renamed/reorganised directories, new tooling or shells, or
  changes to validation steps.

### Cleanup

- Before handoff, remove task-created scratch files, experiments, generated artifacts, dependencies, or code that is no longer needed.
- Before removing an existing managed file, check its references and call sites, then choose the operation that matches the intended target state:
  - To stop managing a file but leave it in the destination, use `chezmoi forget <target-path>`.
  - To stop managing and remove it from the destination, do it **declaratively** so both sides converge on `chezmoi apply`: `git rm` the source file and add its target path (relative to the home dir, globs and templates allowed, branching on `.isWindows`/`.isWSL`) to `home/.chezmoiremove` (create it if missing) in the same commit. Alternatively, rename the source entry with a `remove_` prefix if the installed chezmoi supports it. Avoid `chezmoi destroy`; it only removes the target on the current side. Once both sides have applied the removal, the `.chezmoiremove` entry can be dropped.
  - Use destination paths (for example, `.config/app/config`), not source paths in this repository. Check `git status` and the diff afterward so the source-state change is intentional.
- `.chezmoiignore` is not a cleanup tool. Ignoring a path leaves both the source file in this repo and the target file in the home dir untouched; it only stops chezmoi from applying it. Use `forget` or `.chezmoiremove` for unused files instead of ignoring them.
  - Use `.chezmoiignore` for OS/feature-conditional exclusions (via the data above) and files generated at runtime that chezmoi must not overwrite.
  - Patterns are **target paths** relative to the home dir (`.config/foo`), not source names (`dot_config/foo`).
  - When removing a managed file or the thing that generated an ignored file, also drop its now-stale `.chezmoiignore` entry. Verify with `chezmoi ignored` and `chezmoi managed` for both variants.
- Preserve intentional outputs, tests, and documentation.
- Do not delete pre-existing or untracked user changes as cleanup. Limit removals to artifacts created for the current task unless explicitly asked otherwise.

## Security and secrets

- **Never** commit tokens, passwords, private keys, or API keys in plain text.
  Only the SSH **public** key (`signingKey`) is in the config defaults.
- Use `.tmpl`, environment variables, Bitwarden (`bw`), or chezmoi encryption for sensitive values.
- Corporate CA certificates go in `~/.config/certs/` on the machine, never in
  the repo (`*.crt`, `*.pem`, `*.key` are git-ignored).
- Do not log secrets in scripts.

## Validation before handoff

On the side your change affects, run the lightweight checks:

```text
chezmoi diff
chezmoi apply --dry-run --verbose
```

`just validate` runs both; `just --list` shows the other recipes.

### Testing both variants without touching a real home

Never modify the real chezmoi state, config, home directory or WSL distro
while testing. Use a scratch dir and pass **all** isolation flags:

```powershell
$repo = '<repo root>'; $s = '<scratch dir>'; $v = 'wsl'   # or 'windows'
$flags = @('--source', $repo, '--destination', "$s\dest-$v", '--config', "$s\cfg-$v.yaml",
           '--persistent-state', "$s\state-$v.boltdb", '--cache', "$s\cache-$v", '--no-tty')
chezmoi managed @flags
chezmoi ignored @flags
chezmoi apply --dry-run --verbose @flags
Get-Content <file> -Raw | chezmoi execute-template @flags   # render one template or script
```

- Windows config: render the real template into the scratch file:
  `Get-Content $repo\home\.chezmoi.yaml.tmpl -Raw | chezmoi execute-template --init --source $repo --no-tty`.
- WSL config: hand-write `cfg-wsl.yaml` with `isWSL: true`, `isWindows: false`,
  `isLinux: true` and every data key (`name`, `email`, `personalEmail`,
  `signingKey`, `githubOrg`, `wslDistro`, `windowsUser`, `obsidianVault`,
  `features.docker/agentSandbox/powertoys/glazewm`). Also test a variant with all
  features off and an empty `signingKey`.
- Allowed: `execute-template`, `cat`, `managed`, `ignored`, `data`, `diff`,
  `doctor`, `apply --dry-run`. Never `apply` without `--dry-run`, never `init`
  against a real config, never `update`.
- PowerShell: parse rendered `.ps1` with
  `[System.Management.Automation.Language.Parser]::ParseFile(...)` and check
  for non-ASCII bytes (in the sources too).
- Bash: render to the scratch dir, then `wsl.exe -e bash -n /mnt/c/...`
  (syntax check only; never run provisioning scripts or install anything in
  WSL from a test). Use `shellcheck` when it is available.
- JSON: the rendered `~/.claude/settings.json` must parse in every variant.
- Line endings: no CR bytes or BOMs in the repo.

## What to include in PRs or handoff notes

- What changed
- Why the change was needed
- How it was validated (which variants)
- Any assumptions or limitations

## Avoid

- Adding unrequested "nice-to-have" features
- Upgrading unrelated dependencies as part of small fixes
- Touching unrelated files for formatting-only changes
