[CmdletBinding()]
param(
    [switch]$TestMode,
    [string]$StateRoot,
    [string]$CodexHome,
    [switch]$NoPathUpdate
)

. "$PSScriptRoot\common.ps1"

if ($env:OS -ne 'Windows_NT') {
    throw 'This installer must run on Windows.'
}

if ([string]::IsNullOrWhiteSpace($StateRoot)) {
    $StateRoot = Get-DefaultStateRoot
}
if ([string]::IsNullOrWhiteSpace($CodexHome)) {
    $CodexHome = Get-DefaultCodexHome
}

$StateRoot = Get-FullPath -Path $StateRoot
$CodexHome = Get-FullPath -Path $CodexHome
$defaultStateRoot = Get-FullPath -Path (Get-DefaultStateRoot)
$defaultCodexHome = Get-FullPath -Path (Get-DefaultCodexHome)

if (-not $TestMode) {
    if (-not [string]::Equals($StateRoot, $defaultStateRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'A custom StateRoot is allowed only in test mode.'
    }
    if (-not [string]::Equals($CodexHome, $defaultCodexHome, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'A custom CodexHome is allowed only in test mode.'
    }
}

Assert-StateRootIsOwnedOrEmpty -StateRoot $StateRoot

$profilePath = [System.IO.Path]::Combine($CodexHome, $script:ProfileFileName)
$profileMarkerPath = Get-ProfileMarkerPath -CodexHome $CodexHome
if ((Test-Path -LiteralPath $profilePath -PathType Leaf) -and
    -not (Test-OwnerMarker -Path $profileMarkerPath)) {
    throw "Refusing to overwrite an unowned Codex profile: $profilePath"
}

$secureKey = if ($TestMode) {
    ConvertTo-SecureString -String 'test-neuroapi-token' -AsPlainText -Force
} else {
    Write-Host ''
    Write-Host 'NeuroAPI will store the key with Windows DPAPI for this user on this computer.'
    Read-Host -Prompt 'Paste your NeuroAPI API key' -AsSecureString
}
if ($secureKey.Length -eq 0) {
    throw 'The NeuroAPI API key cannot be empty.'
}

$binRoot = [System.IO.Path]::Combine($StateRoot, 'bin')
$configRoot = [System.IO.Path]::Combine($StateRoot, 'config')
$secretRoot = [System.IO.Path]::Combine($StateRoot, 'secret')
$secretPath = [System.IO.Path]::Combine($secretRoot, 'api-key.dpapi')
$helperPath = [System.IO.Path]::Combine($binRoot, 'get-neuroapi-key.ps1')
$claudeSettingsPath = [System.IO.Path]::Combine($configRoot, 'claude-settings.json')

Ensure-Directory -Path $StateRoot
Write-OwnerMarker -Path (Get-StateMarkerPath -StateRoot $StateRoot)
Ensure-Directory -Path $binRoot
Ensure-Directory -Path $configRoot
Ensure-Directory -Path $secretRoot
Ensure-Directory -Path $CodexHome

$ciphertext = ConvertFrom-SecureString -SecureString $secureKey
Write-Utf8NoBom -Path $secretPath -Content $ciphertext
$secureKey.Clear()

Copy-Item -LiteralPath "$PSScriptRoot\get-neuroapi-key.ps1" -Destination $helperPath -Force

$tomlHelperPath = ConvertTo-TomlBasicString -Value $helperPath
$tomlSecretPath = ConvertTo-TomlBasicString -Value $secretPath
$profile = @"
# Managed by the NeuroAPI Agents installer.
model = "gpt-5.6-sol"
model_provider = "neuroapi"

[model_providers.neuroapi]
name = "NeuroAPI"
base_url = "https://neuroapi.host/v1"
wire_api = "responses"

[model_providers.neuroapi.auth]
command = "powershell.exe"
args = ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", $tomlHelperPath, "-SecretPath", $tomlSecretPath]
timeout_ms = 5000
refresh_interval_ms = 300000
"@
Write-Utf8NoBom -Path $profilePath -Content $profile
Write-OwnerMarker -Path $profileMarkerPath

$helperCommand = 'powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' +
    $helperPath + '" -SecretPath "' + $secretPath + '"'
$claudeSettings = [ordered]@{
    '$schema' = 'https://json.schemastore.org/claude-code-settings.json'
    apiKeyHelper = $helperCommand
    env = [ordered]@{
        ANTHROPIC_BASE_URL = 'https://neuroapi.host'
        ANTHROPIC_MODEL = 'claude-sonnet-4-5'
    }
} | ConvertTo-Json -Depth 5
Write-Utf8NoBom -Path $claudeSettingsPath -Content $claudeSettings

$codexLauncher = @"
@echo off
codex --profile neuroapi-host %*
"@
$claudeLauncher = @"
@echo off
claude --settings "$claudeSettingsPath" %*
"@
Write-Utf8NoBom -Path ([System.IO.Path]::Combine($binRoot, 'codex-neuroapi.cmd')) -Content $codexLauncher
Write-Utf8NoBom -Path ([System.IO.Path]::Combine($binRoot, 'claude-neuroapi.cmd')) -Content $claudeLauncher

if (-not $TestMode -and -not $NoPathUpdate) {
    Add-UserPathEntry -Entry $binRoot
}

Write-Host ''
Write-Host 'NeuroAPI setup is complete.'
Write-Host "Codex launcher:  $binRoot\codex-neuroapi.cmd"
Write-Host "Claude launcher: $binRoot\claude-neuroapi.cmd"
Write-Host 'Open a new terminal, then run codex-neuroapi or claude-neuroapi.'
if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    Write-Warning 'Codex CLI is not installed or is not on PATH.'
}
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Warning 'Claude Code is not installed or is not on PATH.'
}
