# Windows installer for claude-rig. Symlinks this repo's files into place (needs Developer
# Mode or an elevated shell for symlinks) and renders the ccstatusline layout with this
# machine's paths. Safe to re-run; real files it displaces are renamed *.bak-<stamp>.
#
#   .\install.ps1 [-ConfigDir <path>] [-Python <python.exe>]
#
# ConfigDir defaults to $env:CLAUDE_CONFIG_DIR, then ~\.claude. Python defaults to the
# python.org 3.12 install, then whatever `python` resolves to.
[CmdletBinding()]
param(
    [string]$ConfigDir = $env:CLAUDE_CONFIG_DIR,
    [string]$Python
)
$ErrorActionPreference = 'Stop'
$R = $PSScriptRoot
$HomeDir = $env:USERPROFILE
if (-not $ConfigDir) { $ConfigDir = Join-Path $HomeDir '.claude' }
if (-not $Python) {
    $candidate = Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe'
    if (Test-Path $candidate) { $Python = $candidate }
    else { $Python = (Get-Command python -ErrorAction Stop).Source }
}
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Backup-IfReal([string]$path) {
    if ((Test-Path -LiteralPath $path) -and -not ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Move-Item -LiteralPath $path -Destination "$path.bak-$stamp"
        Write-Host "backed up $path"
    }
}

function Link([string]$rel, [string]$dst) {
    $src = Join-Path $R $rel
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    Backup-IfReal $dst
    if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Force -Recurse:$false }
    New-Item -ItemType SymbolicLink -Path $dst -Target $src | Out-Null
    Write-Host "linked $dst"
}

# ccstatusline layout: custom-command widgets need this machine's python and paths, so this
# one is rendered, not linked. /theme edits the rendered copy; re-run install to refresh it.
$ccsDir = Join-Path $HomeDir '.config\ccstatusline'
New-Item -ItemType Directory -Force $ccsDir | Out-Null
$usageBar = Join-Path $ccsDir 'usage-bar.py'
$streaks = Join-Path $ConfigDir 'bin\streaks.py'
$json = Get-Content (Join-Path $R 'ccstatusline\settings.json') -Raw
$json = $json -replace '/Users/[^/\s"]+/\.config/ccstatusline/usage-bar\.py', ('\"' + ($Python -replace '\\', '\\') + '\" \"' + ($usageBar -replace '\\', '\\') + '\"')
$json = $json -replace '/Users/[^/\s"]+/\.claude[^/\s"]*/bin/streaks\.py', ('\"' + ($Python -replace '\\', '\\') + '\" \"' + ($streaks -replace '\\', '\\') + '\"')
$dst = Join-Path $ccsDir 'settings.json'
Backup-IfReal $dst
[IO.File]::WriteAllText($dst, $json, [Text.UTF8Encoding]::new($false))
Write-Host "rendered $dst"

# Theme marker read by ccs-theme and wezterm.lua. Seeded once; /theme rewrites it.
$marker = Join-Path $ccsDir '.theme'
if (-not (Test-Path $marker)) { [IO.File]::WriteAllText($marker, "nightshade`n"); Write-Host "seeded $marker" }

Link 'ccstatusline\usage-bar.py' $usageBar
foreach ($f in 'ccs-theme', 'spinner-pack', 'streaks.py', 'usage-guard') { Link "claude\bin\$f" (Join-Path $ConfigDir "bin\$f") }
foreach ($f in 'spinner.md', 'theme.md') { Link "claude\commands\$f" (Join-Path $ConfigDir "commands\$f") }
Link 'claude\spinner-packs' (Join-Path $ConfigDir 'spinner-packs')
Link 'wezterm\wezterm.lua' (Join-Path $HomeDir '.wezterm.lua')

Write-Host ''
Write-Host "Python for hooks and widgets: $Python"
Write-Host "Now merge claude\settings-snippets.json into $ConfigDir\settings.json (statusLine, spinnerVerbs, hooks),"
Write-Host "using `"$Python`" `"$ConfigDir\bin\<script>`" as each hook command, and install ccstatusline"
Write-Host "(npm i -g ccstatusline@2.2.27). WezTerm reloads ~\.wezterm.lua on its own."
