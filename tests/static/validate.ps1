Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$files = @(
  (Join-Path $repoRoot 'README.md'),
  (Join-Path $repoRoot 'README.en.md'),
  (Join-Path $repoRoot 'SECURITY.md'),
  (Join-Path $repoRoot 'docs\security.md'),
  (Join-Path $repoRoot 'docs\manual-setup.md'),
  (Join-Path $repoRoot 'docs\troubleshooting.md')
)

foreach ($file in $files) {
  if (-not (Test-Path $file)) {
    throw "Missing expected file: $file"
  }
}

$content = Get-ChildItem $repoRoot -Recurse -File |
  Where-Object { $_.FullName -notmatch '\\\.git\\' } |
  ForEach-Object { [PSCustomObject]@{ Path = $_.FullName; Text = Get-Content $_.FullName -Raw } }

$secretPatterns = @(
  '(?i)\bghp_[A-Za-z0-9]{20,}\b',
  '(?i)\bgho_[A-Za-z0-9]{20,}\b',
  '(?i)\bgithub_pat_[A-Za-z0-9_]{20,}\b',
  '(?i)\bsk-[A-Za-z0-9]{20,}\b',
  '(?i)\bANTHROPIC_API_KEY\s*=\s*[^\s]+',
  '(?i)\bNEUROAPI_API_KEY\s*=\s*[^\s]+',
  '(?i)\bapi[_-]?key\s*[:=]\s*[^\s]+'
)

foreach ($item in $content) {
  foreach ($pattern in $secretPatterns) {
    if ($item.Text -match $pattern) {
      throw "Potential secret pattern found in $($item.Path) with pattern $pattern"
    }
  }
}

$readme = Get-Content (Join-Path $repoRoot 'README.md') -Raw
if ($readme -notmatch 'neuroapi\.host') { throw 'README.md must link to neuroapi.host' }
if ($readme -notmatch 'Codex CLI') { throw 'README.md must mention Codex CLI' }
if ($readme -notmatch 'Claude Code') { throw 'README.md must mention Claude Code' }

$security = Get-Content (Join-Path $repoRoot 'docs\security.md') -Raw
if ($security -notmatch 'DPAPI') { throw 'docs/security.md must mention DPAPI' }
if ($security -notmatch 'Keychain') { throw 'docs/security.md must mention Keychain' }

Write-Host 'Static validation passed.'
