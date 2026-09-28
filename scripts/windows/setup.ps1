[CmdletBinding()]
param(
    [switch]$TestMode,
    [string]$StateRoot,
    [string]$CodexHome,
    [switch]$NoPathUpdate
)

. "$PSScriptRoot\common.ps1"
. "$PSScriptRoot\managed-catalog.ps1"

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

if ($TestMode -and (
    [string]::Equals($StateRoot, $defaultStateRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    [string]::Equals($CodexHome, $defaultCodexHome, [System.StringComparison]::OrdinalIgnoreCase)
)) {
    throw 'Test mode requires isolated StateRoot and CodexHome paths.'
}
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
    $testToken = if ([string]::IsNullOrEmpty($env:NEUROAPI_AGENTS_TEST_TOKEN)) { 'test-neuroapi-token' } else { $env:NEUROAPI_AGENTS_TEST_TOKEN }
    ConvertTo-SecureString -String $testToken -AsPlainText -Force
} else {
    Write-Host ''
    Write-Host 'NeuroAPI will store the key with Windows DPAPI for this user on this computer.'
    Read-Host -Prompt 'Paste your NeuroAPI API key' -AsSecureString
}
if ($secureKey.Length -eq 0) {
    throw 'The NeuroAPI API key cannot be empty.'
}

if (-not $TestMode) {
    # Both checks are read-only. A rejected key or broken client leaves existing
    # credentials and configuration untouched.
    Assert-NeuroAPIKeyCatalogs -SecureKey $secureKey
}

$binRoot = [System.IO.Path]::Combine($StateRoot, 'bin')
$configRoot = [System.IO.Path]::Combine($StateRoot, 'config')
$secretRoot = [System.IO.Path]::Combine($StateRoot, 'secret')
$secretPath = [System.IO.Path]::Combine($secretRoot, 'api-key.dpapi')
$helperPath = [System.IO.Path]::Combine($binRoot, 'get-neuroapi-key.ps1')
$claudeSettingsPath = [System.IO.Path]::Combine($configRoot, 'claude-settings.json')

if (-not $TestMode) {
    Ensure-Directory -Path $StateRoot
    Set-NeuroAPIPrivateDirectory -Path $StateRoot
    Write-OwnerMarker -Path (Get-StateMarkerPath -StateRoot $StateRoot)
    Ensure-Directory -Path $binRoot
    $installedClients = @(Ensure-NeuroAPIClients -StateRoot $StateRoot)
}

Ensure-Directory -Path $StateRoot
Set-NeuroAPIPrivateDirectory -Path $StateRoot
Write-OwnerMarker -Path (Get-StateMarkerPath -StateRoot $StateRoot)
Ensure-Directory -Path $binRoot
Ensure-Directory -Path $configRoot
Ensure-Directory -Path $secretRoot
Ensure-Directory -Path $CodexHome

$transactionId = [Guid]::NewGuid().ToString('N')
$stageRoot = Join-Path $StateRoot ('setup-stage-' + $transactionId)
$promoted = New-Object System.Collections.ArrayList
$pendingFiles = New-Object System.Collections.ArrayList
$backupFiles = New-Object System.Collections.ArrayList
$rollbackFailed = $false
try {
    Ensure-Directory -Path $stageRoot
    Set-NeuroAPIPrivateDirectory -Path $stageRoot
    Ensure-Directory -Path (Join-Path $stageRoot 'bin')
    $ciphertext = ConvertFrom-SecureString -SecureString $secureKey
    Write-Utf8NoBom -Path (Join-Path $stageRoot 'api-key.dpapi') -Content $ciphertext
    $ciphertext = $null
    $secureKey.Clear()

    foreach ($scriptName in @('get-neuroapi-key.ps1', 'common.ps1', 'managed-catalog.ps1', 'launch-neuroapi.ps1')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $scriptName) -Destination (Join-Path (Join-Path $stageRoot 'bin') $scriptName)
    }

    $tomlHelperPath = ConvertTo-TomlBasicString -Value $helperPath
    $tomlSecretPath = ConvertTo-TomlBasicString -Value $secretPath
    $profile = @"
# Managed by the NeuroAPI Agents installer.
model_provider = "neuroapi"
web_search = "disabled"

# These Codex-hosted tools are not part of the NeuroAPI Responses contract.
[features]
multi_agent = false
goals = false
apps = false
browser_use = false

[model_providers.neuroapi]
name = "NeuroAPI"
base_url = "https://neuroapi.host/v1/codex"
wire_api = "responses"
supports_websockets = true

[model_providers.neuroapi.auth]
command = "powershell.exe"
args = ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", $tomlHelperPath, "-SecretPath", $tomlSecretPath]
timeout_ms = 5000
refresh_interval_ms = 300000
"@
    Write-Utf8NoBom -Path (Join-Path $stageRoot 'profile.toml') -Content $profile
    Write-OwnerMarker -Path (Join-Path $stageRoot 'profile-marker')

    $helperCommand = 'powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' +
        $helperPath + '" -SecretPath "' + $secretPath + '"'
    $claudeSettings = [ordered]@{
        '$schema' = 'https://json.schemastore.org/claude-code-settings.json'
        apiKeyHelper = $helperCommand
        env = [ordered]@{
            ANTHROPIC_BASE_URL = 'https://neuroapi.host/v1/claude-code'
        }
    } | ConvertTo-Json -Depth 5
    Write-Utf8NoBom -Path (Join-Path $stageRoot 'claude-settings.json') -Content $claudeSettings

    $codexLauncher = @"
@echo off
setlocal
set "PSModulePath="
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch-neuroapi.ps1" codex %*
exit /b %errorlevel%
"@
    $claudeLauncher = @"
@echo off
setlocal
set "PSModulePath="
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch-neuroapi.ps1" claude %*
exit /b %errorlevel%
"@
    Write-Utf8NoBom -Path (Join-Path $stageRoot 'codex-neuroapi.cmd') -Content $codexLauncher
    Write-Utf8NoBom -Path (Join-Path $stageRoot 'claude-neuroapi.cmd') -Content $claudeLauncher

    # The credential is promoted last. Every file replacement keeps an
    # encrypted/installer-owned backup until the entire update succeeds.
    $files = @(
        [pscustomobject]@{ Source = (Join-Path $stageRoot 'bin/get-neuroapi-key.ps1'); Target = $helperPath; Name = 'get-neuroapi-key.ps1' },
        [pscustomobject]@{ Source = (Join-Path $stageRoot 'bin/common.ps1'); Target = (Join-Path $binRoot 'common.ps1'); Name = 'common.ps1' },
        [pscustomobject]@{ Source = (Join-Path $stageRoot 'bin/managed-catalog.ps1'); Target = (Join-Path $binRoot 'managed-catalog.ps1'); Name = 'managed-catalog.ps1' },
        [pscustomobject]@{ Source = (Join-Path $stageRoot 'bin/launch-neuroapi.ps1'); Target = (Join-Path $binRoot 'launch-neuroapi.ps1'); Name = 'launch-neuroapi.ps1' },
        [pscustomobject]@{ Source = (Join-Path $stageRoot 'profile.toml'); Target = $profilePath; Name = 'neuroapi-host.config.toml' },
        [pscustomobject]@{ Source = (Join-Path $stageRoot 'profile-marker'); Target = $profileMarkerPath; Name = 'profile-marker' },
        [pscustomobject]@{ Source = (Join-Path $stageRoot 'claude-settings.json'); Target = $claudeSettingsPath; Name = 'claude-settings.json' },
        [pscustomobject]@{ Source = (Join-Path $stageRoot 'codex-neuroapi.cmd'); Target = (Join-Path $binRoot 'codex-neuroapi.cmd'); Name = 'codex-neuroapi.cmd' },
        [pscustomobject]@{ Source = (Join-Path $stageRoot 'claude-neuroapi.cmd'); Target = (Join-Path $binRoot 'claude-neuroapi.cmd'); Name = 'claude-neuroapi.cmd' },
        [pscustomobject]@{ Source = (Join-Path $stageRoot 'api-key.dpapi'); Target = $secretPath; Name = 'api-key.dpapi' }
    )
    foreach ($file in $files) {
        $target = $file.Target
        $pending = $target + '.new.' + $transactionId
        $backup = $target + '.backup.' + $transactionId
        if ((Test-Path -LiteralPath $pending) -or (Test-Path -LiteralPath $backup)) { throw 'Setup transaction path is occupied.' }
        $existed = Test-Path -LiteralPath $target
        if ($existed) {
            $item = Get-Item -LiteralPath $target -Force
            if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                throw 'Refusing to replace a directory or linked setup file.'
            }
        }
        Copy-Item -LiteralPath $file.Source -Destination $pending -ErrorAction Stop
        [void]$pendingFiles.Add($pending)
        if ($existed) {
            [IO.File]::Replace($pending, $target, $backup)
            [void]$backupFiles.Add($backup)
        } else {
            [IO.File]::Move($pending, $target)
        }
        [void]$promoted.Add([pscustomobject]@{ Target = $target; Backup = $backup; Existed = $existed })
        if ($TestMode -and $env:NEUROAPI_AGENTS_TEST_FAIL_AFTER -ceq $file.Name) {
            throw 'Simulated setup transaction failure.'
        }
    }
} catch {
    $originalError = $_
    for ($i = $promoted.Count - 1; $i -ge 0; $i--) {
        $entry = $promoted[$i]
        try {
            if ($entry.Existed) {
                if (Test-Path -LiteralPath $entry.Target) {
                    [IO.File]::Replace($entry.Backup, $entry.Target, $null)
                } else {
                    [IO.File]::Move($entry.Backup, $entry.Target)
                }
            } elseif (Test-Path -LiteralPath $entry.Target) {
                [IO.File]::Delete($entry.Target)
            }
        } catch {
            $rollbackFailed = $true
        }
    }
    if ($rollbackFailed) { throw 'Не удалось полностью восстановить прежнюю настройку NeuroAPI; сохраните резервные DPAPI-файлы и обратитесь в поддержку.' }
    throw $originalError
} finally {
    $secureKey.Clear()
    foreach ($pending in $pendingFiles) {
        if (Test-Path -LiteralPath $pending) { Remove-Item -LiteralPath $pending -Force -ErrorAction SilentlyContinue }
    }
    if (-not $rollbackFailed) {
        foreach ($backup in $backupFiles) {
            if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue }
        }
    }
    if (Test-Path -LiteralPath $stageRoot) { Remove-Item -LiteralPath $stageRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

if (-not $TestMode -and -not $NoPathUpdate) {
    try {
        Add-OwnedUserPathEntry -Entry $binRoot -StateRoot $StateRoot
        if ($installedClients -contains 'claude') {
            Add-OwnedUserPathEntry -Entry (Join-Path $env:USERPROFILE '.local/bin') -StateRoot $StateRoot
        }
    } catch {
        Write-Warning 'Клиенты настроены, но PATH не обновлён. Запускайте команды по полному пути, указанному ниже.'
    }
}

Write-Host ''
Write-Host 'NeuroAPI setup is complete.'
Write-Host "Codex launcher:  $binRoot\codex-neuroapi.cmd"
Write-Host "Claude launcher: $binRoot\claude-neuroapi.cmd"
Write-Host 'Open a new terminal, then run codex-neuroapi or claude-neuroapi.'
