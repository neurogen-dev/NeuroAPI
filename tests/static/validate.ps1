Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Read-RepoFile {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    return Get-Content -LiteralPath (Join-Path $repoRoot $RelativePath) -Raw
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Needle,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if ($Text.IndexOf($Needle, [System.StringComparison]::Ordinal) -lt 0) {
        throw $Message
    }
}

function Assert-NotMatches {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if ($Text -match $Pattern) {
        throw $Message
    }
}

$requiredFiles = @(
    'README.md',
    'README.en.md',
    'SECURITY.md',
    'LICENSE',
    'setup-windows.bat',
    'uninstall-windows.bat',
    'setup-macos.command',
    'uninstall-macos.command',
    'scripts/windows/setup.ps1',
    'scripts/windows/get-neuroapi-key.ps1',
    'scripts/windows/uninstall.ps1',
    'scripts/macos/install.sh',
    'scripts/macos/get-neuroapi-key.sh',
    'scripts/macos/uninstall.sh',
    'docs/security.md',
    'docs/manual-setup.md',
    'docs/troubleshooting.md'
)
foreach ($file in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $file) -PathType Leaf)) {
        throw "Required public file is missing: $file"
    }
}

$windowsSetup = Read-RepoFile 'scripts/windows/setup.ps1'
Assert-Contains $windowsSetup 'Read-Host -Prompt ''Paste your NeuroAPI API key'' -AsSecureString' `
    'Windows setup must keep masked interactive key entry.'
Assert-Contains $windowsSetup 'ConvertFrom-SecureString -SecureString $secureKey' `
    'Windows setup must keep DPAPI protection without a supplied encryption key.'
Assert-NotMatches $windowsSetup '(?i)\[string\]\s*\$ApiKey' `
    'Windows setup must not accept an API key string parameter.'
Assert-NotMatches $windowsSetup '(?i)ANTHROPIC_AUTH_TOKEN' `
    'Windows setup must not persist a Claude token.'

$windowsWrapper = Read-RepoFile 'setup-windows.bat'
Assert-NotMatches $windowsWrapper '%\*' `
    'The Windows setup wrapper must not forward command-line arguments.'
Assert-Contains $windowsWrapper 'set "PSModulePath="' `
    'The Windows wrapper must isolate Windows PowerShell from inherited module paths.'

$macSetup = Read-RepoFile 'scripts/macos/install.sh'
Assert-Contains $macSetup '"$SECURITY_BIN" add-generic-password' `
    'macOS setup must use the Keychain security command.'
Assert-Contains $macSetup '  -w' `
    'macOS setup must leave credential prompting to the final -w option.'
Assert-Contains $macSetup 'Refusing to overwrite an unowned Keychain item' `
    'macOS setup must protect pre-existing Keychain items.'
Assert-NotMatches $macSetup '(?i)(api_key|token|secret)=' `
    'macOS setup must not store the entered key in a shell variable.'
Assert-NotMatches $macSetup '\|\s*"\$SECURITY_BIN"\s+add-generic-password' `
    'macOS setup must not pipe a key into the Keychain command.'

$macWrapper = Read-RepoFile 'setup-macos.command'
Assert-NotMatches $macWrapper '"\$@"' `
    'The macOS setup wrapper must not forward command-line arguments.'

$macUninstall = Read-RepoFile 'scripts/macos/uninstall.sh'
Assert-Contains $macUninstall 'KEYCHAIN_ITEM_IS_OWNED' `
    'macOS uninstall must require an installer-owned Keychain marker.'

$readme = Read-RepoFile 'README.md'
Assert-Contains $readme 'DPAPI' 'README must explain Windows secret storage.'
Assert-Contains $readme 'Keychain' 'README must explain macOS secret storage.'
Assert-Contains $readme 'https://neuroapi.host' 'README must link to the public NeuroAPI site.'

$denyPatterns = @(
    '(?i)\bghp_[A-Za-z0-9]{20,}\b',
    '(?i)\bgithub_pat_[A-Za-z0-9_]{20,}\b',
    '(?i)\bsk-[A-Za-z0-9]{20,}\b',
    '(?i)\b(AKIA|ASIA)[0-9A-Z]{16}\b',
    '(?i)\bAIza[0-9A-Za-z_-]{20,}\b',
    '(?i)\b(xox[baprs]-[A-Za-z0-9-]{10,})\b',
    '(?i)BEGIN (RSA|EC|OPENSSH|PRIVATE) PRIVATE KEY',
    '(?i)curl[^\r\n|]*\|\s*(ba)?sh\b'
)

$textExtensions = @(
    '.ps1', '.sh', '.command', '.bat', '.md', '.json', '.toml', '.txt', '.yml', '.yaml'
)
$textFiles = Get-ChildItem -LiteralPath $repoRoot -Recurse -File |
    Where-Object {
        $_.FullName -notmatch '(^|[\\/])\.git([\\/]|$)' -and
        $textExtensions -contains $_.Extension
    }

foreach ($file in $textFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($pattern in $denyPatterns) {
        if ($content -match $pattern) {
            throw "Safety scan matched '$pattern' in $($file.FullName)."
        }
    }
}

Write-Host 'Static public-repository validation passed.'
