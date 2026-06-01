#Requires -Version 5
<#
.SYNOPSIS
  Awesome CC Statusline installer for Windows (PowerShell).

.DESCRIPTION
  1. Ensures `jq` is installed (auto via winget/scoop/choco).
  2. Ensures Git Bash exists (installs Git via winget if missing) so Claude Code
     can run the bash statusline script on Windows.
  3. Copies the chosen size script to ~/.claude/awesome-statusline.sh
  4. Patches settings.json -> statusLine (existing settings preserved + backup).

.EXAMPLE
  ./install.ps1            # install
  ./install.ps1 l          # by abbreviation
  ./install.ps1 large      # by full name
#>
param([string]$Size)

$ErrorActionPreference = 'Stop'

function Write-Info($m) { Write-Host $m -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host $m -ForegroundColor Green }
function Write-Err($m)  { Write-Host $m -ForegroundColor Red }

function Normalize-Mode([string]$s) {
  switch ($s.ToLower()) {
    'xs'     { 'xsmall' } 'xsmall' { 'xsmall' }
    's'      { 'small' }  'small'  { 'small' }
    'm'      { 'medium' } 'medium' { 'medium' }
    'l'      { 'large' }  'large'  { 'large' }
    'xl'     { 'xlarge' } 'xlarge' { 'xlarge' }
    default  { $null }
  }
}

# --- paths ------------------------------------------------------------------
$ClaudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$Settings  = Join-Path $ClaudeDir 'settings.json'
$Dest      = Join-Path $ClaudeDir 'awesome-statusline.sh'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SrcDir    = Join-Path $ScriptDir 'scripts'
$RepoRaw   = if ($env:AWESOME_STATUSLINE_RAW) { $env:AWESOME_STATUSLINE_RAW } else { 'https://raw.githubusercontent.com/AwesomeJun/CC-statusline/main' }

# --- dependency installer ---------------------------------------------------
function Ensure-Tool([string]$Cmd, [string]$WingetId, [string]$ScoopPkg, [string]$ChocoPkg) {
  if (Get-Command $Cmd -ErrorAction SilentlyContinue) { return }
  Write-Info "$Cmd not found - installing..."
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install --silent --accept-package-agreements --accept-source-agreements -e --id $WingetId
  } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
    scoop install $ScoopPkg
  } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
    choco install $ChocoPkg -y
  } else {
    Write-Err "No package manager (winget/scoop/choco) found. Please install $Cmd manually."
    exit 1
  }
}

function Test-GitBash {
  if (Get-Command bash -ErrorAction SilentlyContinue) { return $true }
  foreach ($p in @("$env:ProgramFiles\Git\bin\bash.exe", "${env:ProgramFiles(x86)}\Git\bin\bash.exe")) {
    if (Test-Path $p) { return $true }
  }
  return $false
}

function Copy-JqBeside([string]$ClaudeDir) {
  # Place a jq.exe next to the statusline script so it is found even when a
  # winget-installed jq is not on PATH (a very common Windows failure mode where
  # the statusline renders blank because every jq call fails). The script adds
  # its own directory to PATH at runtime, so this jq is always reachable.
  $dest = Join-Path $ClaudeDir 'jq.exe'
  if (Test-Path $dest) { return $true }
  # 1) jq already resolvable -> copy from there
  $cmd = Get-Command jq -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) {
    Copy-Item $cmd.Source $dest -Force
    return $true
  }
  # 2) winget often does not refresh PATH in the current session — search the
  #    common package locations directly.
  $roots = @(
    (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'),
    (Join-Path $HOME 'scoop\apps\jq'),
    "$env:ProgramData\chocolatey\bin"
  ) | Where-Object { $_ -and (Test-Path $_) }
  foreach ($r in $roots) {
    $hit = Get-ChildItem -Path $r -Recurse -Filter 'jq.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hit) { Copy-Item $hit.FullName $dest -Force; return $true }
  }
  return $false
}

# --- pick size --------------------------------------------------------------
$Mode = 'large'
if ($Size) {
  $Mode = Normalize-Mode $Size
  if (-not $Mode) {
    Write-Err "Unknown size: '$Size'"
    Write-Err "Valid: xsmall|xs  small|s  medium|m  large|l  xlarge|xl"
    exit 1
  }
}

# --- ensure dependencies ----------------------------------------------------
Ensure-Tool -Cmd 'jq' -WingetId 'jqlang.jq' -ScoopPkg 'jq' -ChocoPkg 'jq'
if (-not (Test-GitBash)) {
  Write-Info "Git Bash not found - installing Git (provides bash to run the statusline)..."
  Ensure-Tool -Cmd 'git' -WingetId 'Git.Git' -ScoopPkg 'git' -ChocoPkg 'git'
}

# --- install the script -----------------------------------------------------
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
$Src = Join-Path $SrcDir "awesome-statusline-$Mode.sh"
if (Test-Path $Src) {
  Copy-Item $Src $Dest -Force
} else {
  Write-Info "Local scripts/ not found, downloading size '$Mode' from repo..."
  Invoke-WebRequest -Uri "$RepoRaw/scripts/awesome-statusline-$Mode.sh" -OutFile $Dest
}

# --- bundle jq beside the script (Windows PATH safety net) ------------------
if (Copy-JqBeside $ClaudeDir) {
  Write-Ok "Bundled jq.exe into $ClaudeDir (works even if jq is not on PATH)."
} else {
  Write-Err "Could not locate jq.exe to bundle. If the statusline renders blank, add jq to PATH manually."
}

# --- patch settings.json ----------------------------------------------------
# Invoke via `bash <script>` instead of the bare path: on Windows a bare `.sh`
# path is opened through its file association (`bash --login -i ...`), which
# spawns blank terminal windows on every refresh and breaks stdin/stdout.
$slObj = [pscustomobject]@{ type = 'command'; command = 'bash ~/.claude/awesome-statusline.sh' }
if (Test-Path $Settings) {
  $backup = "$Settings.backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
  Copy-Item $Settings $backup -Force
  $json = Get-Content $Settings -Raw | ConvertFrom-Json
  if ($json.PSObject.Properties.Name -contains 'statusLine') {
    $json.statusLine = $slObj
  } else {
    $json | Add-Member -NotePropertyName 'statusLine' -NotePropertyValue $slObj
  }
  $json | ConvertTo-Json -Depth 20 | Set-Content $Settings -Encoding UTF8
  Write-Info "Existing settings backed up to: $backup"
} else {
  [pscustomobject]@{ statusLine = $slObj } | ConvertTo-Json -Depth 20 | Set-Content $Settings -Encoding UTF8
}

Write-Ok "Installed Awesome CC Statusline (size: $Mode)"
Write-Host "  script:   $Dest"
Write-Host "  settings: $Settings  (statusLine set)"
Write-Host ""
Write-Host "Change size later:  ./install.ps1 <xsmall|small|medium|large|xlarge>  (or xs/s/m/l/xl)"
Write-Host "Restart Claude Code to see it."
