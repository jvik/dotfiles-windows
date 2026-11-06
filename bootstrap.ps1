<#
.SYNOPSIS
    Bootstrap the Windows side of dotfiles-windows.

.DESCRIPTION
    Run once on a fresh Windows machine, from the repo root:

        powershell -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1

    1. Makes sure winget is available.
    2. Installs Git.Git, twpayne.chezmoi and Microsoft.PowerShell if missing.
    3. Refreshes PATH in this session so the new tools are usable right away.
    4. Makes sure scripts run by chezmoi are allowed (CurrentUser RemoteSigned).
    5. Sets core.autocrlf=false for this repo (if it is a git repo).
    6. chezmoi init --source <this repo> --apply
       (the generated chezmoi config remembers the source dir, so later a
       plain `chezmoi apply` works with no flags).
    7. Prints the next steps for WSL.

    Safe to re-run. Pure ASCII, Windows PowerShell 5.1 compatible.

.PARAMETER PromptDefaults
    Pass --promptDefaults to chezmoi init (accept defaults, no questions).

.PARAMETER NoApply
    Run chezmoi init without --apply (generate config only).
#>
[CmdletBinding()]
param(
    [switch]$PromptDefaults,
    [switch]$NoApply
)

$ErrorActionPreference = 'Stop'
$RepoRoot = $PSScriptRoot
if (-not $RepoRoot) { $RepoRoot = (Get-Location).Path }

function Write-Step([string]$Message) {
    Write-Host ''
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Info([string]$Message) {
    Write-Host "    $Message"
}

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @()
    foreach ($p in @($machine, $user)) {
        if ($p) { $parts += $p.Split(';') | Where-Object { $_ } }
    }
    # winget's portable-package links (chezmoi lives here).
    $links = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
    if ((Test-Path -LiteralPath $links) -and ($parts -notcontains $links)) { $parts += $links }
    $seen = @{}
    $unique = @()
    foreach ($p in $parts) {
        $expanded = [Environment]::ExpandEnvironmentVariables($p)
        $key = $expanded.TrimEnd('\').ToLowerInvariant()
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $unique += $expanded
        }
    }
    $env:Path = $unique -join ';'
}

function Test-WingetPackage([string]$Id) {
    & winget list --id $Id --exact --accept-source-agreements --disable-interactivity | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Install-WingetPackage([string]$Id, [string]$Scope) {
    # An existing install is kept whatever its scope (winget list matches both).
    if (Test-WingetPackage $Id) {
        Write-Info "ok       $Id (already installed)"
        return $true
    }
    $wingetArgs = @('install', '--id', $Id, '--exact', '--source', 'winget', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
    if ($Scope) { $wingetArgs += @('--scope', $Scope) }
    Write-Info ("install  $Id" + $(if ($Scope) { " (scope $Scope)" } else { '' }))
    # Out-Host: keep winget's output out of this function's return value.
    & winget @wingetArgs | Out-Host
    $code = $LASTEXITCODE
    # 0x8A150061 already installed, 0x8A15002B no applicable upgrade
    if (($code -eq 0) -or ($code -eq -1978335135) -or ($code -eq -1978335189)) {
        return $true
    }
    Write-Warning ("winget install {0} failed (exit code 0x{1:X8})." -f $Id, $code)
    return $false
}

function Find-Tool([string]$Name, [string[]]$Fallbacks) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($f in $Fallbacks) {
        if ($f -and (Test-Path -LiteralPath $f -PathType Leaf)) { return $f }
    }
    return $null
}

function Set-RepoAutoCrlf([string]$Git) {
    if (-not $Git) { return }
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot '.git'))) { return }
    & $Git -C $RepoRoot config core.autocrlf false | Out-Host
    if ($LASTEXITCODE -eq 0) {
        Write-Info 'git config core.autocrlf false (this repo only)'
    } else {
        Write-Warning 'Could not set core.autocrlf=false for this repo.'
    }
}

# ---------------------------------------------------------------------------
Write-Step "dotfiles-windows bootstrap (repo: $RepoRoot)"
if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot '.chezmoiroot') -PathType Leaf)) {
    throw "No .chezmoiroot in $RepoRoot. Run this script from the dotfiles-windows repo root."
}

# 1. winget -------------------------------------------------------------------
Write-Step 'Checking winget'
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Info 'winget not found; trying to register App Installer for this user...'
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe'
    } catch {
        Write-Warning ("Registering App Installer failed: {0}" -f $_.Exception.Message)
    }
    Update-SessionPath
    $windowsApps = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    if ((-not (Get-Command winget -ErrorAction SilentlyContinue)) -and (Test-Path -LiteralPath (Join-Path $windowsApps 'winget.exe'))) {
        $env:Path = "$env:Path;$windowsApps"
    }
}
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget is not available. Install "App Installer" from the Microsoft Store (or Company Portal), open a new terminal and re-run this script.'
}
Write-Info ('winget ' + ((& winget --version) -join ''))

# 2. Core tools -----------------------------------------------------------------
Write-Step 'Installing core tools (Git, chezmoi, PowerShell 7)'
$failed = @()
# Scopes match home/.chezmoidata/packages.yaml (the winget script skips
# anything already installed, so the first install decides the scope).
# Git.Git machine scope -> C:\Program Files\Git (may show a UAC prompt).
$corePackages = @(
    @{ Id = 'Git.Git'; Scope = 'machine' },
    @{ Id = 'twpayne.chezmoi'; Scope = 'user' },
    @{ Id = 'Microsoft.PowerShell'; Scope = '' }
)
foreach ($pkg in $corePackages) {
    if (-not (Install-WingetPackage $pkg.Id $pkg.Scope)) { $failed += $pkg.Id }
}

# 3. PATH -------------------------------------------------------------------------
Write-Step 'Refreshing PATH for this session'
Update-SessionPath

$git = Find-Tool 'git' @(
    (Join-Path $env:ProgramFiles 'Git\cmd\git.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe')
)
$chezmoi = Find-Tool 'chezmoi' @(
    (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\chezmoi.exe')
)
$pwsh = Find-Tool 'pwsh' @(
    (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe')
)
if ($git) { Write-Info "git:     $git" } else { Write-Warning 'git not found on PATH.' }
if ($pwsh) { Write-Info "pwsh:    $pwsh" } else { Write-Info 'pwsh:    not found (chezmoi will use Windows PowerShell 5.1 for scripts)' }
if ($chezmoi) { Write-Info "chezmoi: $chezmoi" }
if (-not $chezmoi) {
    throw ('chezmoi is not available (failed installs: {0}). Fix that and re-run.' -f ($failed -join ', '))
}
if (-not $git) {
    Write-Warning 'Continuing without git: chezmoi can apply, but the repo cannot be committed/updated until Git is installed.'
}

# 4. Execution policy ----------------------------------------------------------------
Write-Step 'Checking PowerShell execution policy (chezmoi runs .ps1 scripts)'
$effective = [string](Get-ExecutionPolicy)
Write-Info "effective policy: $effective"
if (@('Restricted', 'AllSigned', 'Undefined') -contains $effective) {
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
        Write-Info 'Set CurrentUser execution policy to RemoteSigned.'
    } catch {
        Write-Warning ("Could not set the CurrentUser execution policy ({0}). If a Group Policy enforces {1}, chezmoi's .ps1 scripts may be blocked." -f $_.Exception.Message, $effective)
    }
}

# 5. Line endings ------------------------------------------------------------------
Write-Step 'Configuring git for this repo'
if (Test-Path -LiteralPath (Join-Path $RepoRoot '.git')) {
    Set-RepoAutoCrlf $git
} else {
    Write-Info 'Not a git repo yet; chezmoi init will create one (core.autocrlf is set afterwards).'
}

# 6. chezmoi init --apply -------------------------------------------------------------
Write-Step 'Running chezmoi init'
$initArgs = @('init', '--source', $RepoRoot)
if (-not $NoApply) { $initArgs += '--apply' }
if ($PromptDefaults) { $initArgs += '--promptDefaults' }
Write-Info ("chezmoi " + ($initArgs -join ' '))
& $chezmoi @initArgs
$chezmoiExit = $LASTEXITCODE
Set-RepoAutoCrlf $git
if ($chezmoiExit -ne 0) {
    throw "chezmoi init failed (exit code $chezmoiExit). Fix the error above and re-run this script (it is safe to re-run)."
}

# 7. Next steps ------------------------------------------------------------------------
$distro = 'Ubuntu'
try {
    $data = (& $chezmoi data --format json) -join "`n" | ConvertFrom-Json
    if ($data.wslDistro) { $distro = [string]$data.wslDistro }
} catch {
    $distro = 'Ubuntu'
}

$wslRepo = $RepoRoot
if ($RepoRoot -match '^([A-Za-z]):\\(.*)$') {
    $wslRepo = '/mnt/' + $Matches[1].ToLowerInvariant() + '/' + ($Matches[2] -replace '\\', '/')
}

Write-Step 'Windows side done. Next steps:'
Write-Host @"

  1. Bitwarden Desktop: sign in, then Settings > "Enable SSH agent".
     The Windows 'ssh-agent' service must be stopped/disabled (chezmoi apply
     prints the exact elevated command if it is not).

  2. .wslconfig changed? Restart the WSL VM so it takes effect:
       wsl --shutdown        (wait ~8 seconds)

  3. Set up the WSL side ($distro). Inside WSL the source lives on ext4
     (~/.local/share/chezmoi), never on /mnt/c:
       wsl -d $distro
     then, either from GitHub (default):
       bash $wslRepo/bootstrap-wsl.sh
     or from this local clone (must be a git repo with at least one commit):
       bash $wslRepo/bootstrap-wsl.sh $wslRepo

  4. After the WSL bootstrap: wsl --shutdown once more (wsl.conf changes),
     then open WezTerm; it starts in WSL:$distro.

  Later updates: chezmoi apply (Windows) / chezmoi apply (WSL); topgrade on
  Windows upgrades winget apps and runs topgrade inside $distro.

"@
if ($failed.Count -gt 0) {
    Write-Warning ('Some core installs failed: {0}. Re-run this script after fixing them.' -f ($failed -join ', '))
}
