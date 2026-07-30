Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$tempRoot = [System.IO.Path]::Combine(
    [System.IO.Path]::GetTempPath(),
    'neuroapi agents test ' + [Guid]::NewGuid().ToString('N')
)
$stateRoot = [System.IO.Path]::Combine($tempRoot, 'state')
$codexHome = [System.IO.Path]::Combine($tempRoot, '.codex')
$sentinel = [System.IO.Path]::Combine($codexHome, 'user-owned.txt')

try {
    New-Item -ItemType Directory -Path $codexHome -Force | Out-Null
    Set-Content -LiteralPath $sentinel -Value 'keep' -Encoding Ascii

    $setupOutput = & "$repoRoot\scripts\windows\setup.ps1" `
        -TestMode `
        -StateRoot $stateRoot `
        -CodexHome $codexHome `
        -NoPathUpdate 6>&1 | Out-String
    Assert-True ($setupOutput -notmatch 'test-neuroapi-token') 'The setup output exposed the dummy token.'

    $profilePath = [System.IO.Path]::Combine($codexHome, 'neuroapi-host.config.toml')
    $profileMarker = [System.IO.Path]::Combine(
        $codexHome,
        '.neuroapi-host.config.toml.neuroapi-agents-owned'
    )
    $secretPath = [System.IO.Path]::Combine($stateRoot, 'secret', 'api-key.dpapi')
    $helperPath = [System.IO.Path]::Combine($stateRoot, 'bin', 'get-neuroapi-key.ps1')
    $settingsPath = [System.IO.Path]::Combine($stateRoot, 'config', 'claude-settings.json')

    Assert-True (Test-Path -LiteralPath $profilePath) 'Codex profile was not created.'
    Assert-True (Test-Path -LiteralPath $profileMarker) 'Codex ownership marker was not created.'
    Assert-True (Test-Path -LiteralPath $secretPath) 'DPAPI secret was not created.'
    Assert-True (Test-Path -LiteralPath $helperPath) 'Credential helper was not installed.'
    Assert-True (Test-Path -LiteralPath $settingsPath) 'Claude settings were not created.'
    Assert-True (
        (Get-Content -LiteralPath $secretPath -Raw) -notmatch 'test-neuroapi-token'
    ) 'The key was stored in plaintext.'

    $helperOutput = & powershell.exe `
        -NoLogo `
        -NoProfile `
        -NonInteractive `
        -ExecutionPolicy Bypass `
        -File $helperPath `
        -SecretPath $secretPath
    Assert-True ($helperOutput -ceq 'test-neuroapi-token') 'Credential helper returned the wrong value.'

    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    Assert-True ($settings.env.ANTHROPIC_BASE_URL -ceq 'https://neuroapi.host') 'Wrong Claude base URL.'
    Assert-True ($settings.env.ANTHROPIC_MODEL -ceq 'claude-sonnet-4-5') 'Wrong Claude model.'
    Assert-True (-not ($settings.PSObject.Properties.Name -contains 'ANTHROPIC_AUTH_TOKEN')) 'Secret leaked into settings.'
    Assert-True ($settings.apiKeyHelper -match 'get-neuroapi-key\.ps1') 'Claude helper is not configured.'
    $claudeHelperOutput = & cmd.exe /d /s /c $settings.apiKeyHelper
    Assert-True ($claudeHelperOutput -ceq 'test-neuroapi-token') 'Claude apiKeyHelper command failed.'

    $pythonExecutable = $null
    $pythonPrefix = @()
    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($null -ne $pyLauncher) {
        $pythonExecutable = $pyLauncher.Source
        $pythonPrefix = @('-3')
    } else {
        $python = Get-Command python -ErrorAction SilentlyContinue
        if ($null -ne $python) {
            $pythonExecutable = $python.Source
        }
    }
    if ($null -ne $pythonExecutable) {
        & $pythonExecutable @pythonPrefix -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 3)'
        if ($LASTEXITCODE -eq 3) {
            Write-Warning 'Skipping TOML parse because local Python is older than 3.11.'
        } else {
            Assert-True ($LASTEXITCODE -eq 0) 'Unable to determine the local Python version.'
            & $pythonExecutable @pythonPrefix -c 'import sys,tomllib; tomllib.load(open(sys.argv[1],''rb''))' $profilePath
            Assert-True ($LASTEXITCODE -eq 0) 'Generated Codex profile is not valid TOML.'
        }
    }

    & "$repoRoot\scripts\windows\setup.ps1" `
        -TestMode `
        -StateRoot $stateRoot `
        -CodexHome $codexHome `
        -NoPathUpdate | Out-Null

    & "$repoRoot\scripts\windows\uninstall.ps1" `
        -TestMode `
        -StateRoot $stateRoot `
        -CodexHome $codexHome `
        -NoPathUpdate | Out-Null

    Assert-True (-not (Test-Path -LiteralPath $stateRoot)) 'Installer state remains after uninstall.'
    Assert-True (-not (Test-Path -LiteralPath $profilePath)) 'Codex profile remains after uninstall.'
    Assert-True (Test-Path -LiteralPath $sentinel) 'Uninstall removed an unrelated file.'

    $unownedState = [System.IO.Path]::Combine($tempRoot, 'unowned-state')
    New-Item -ItemType Directory -Path $unownedState -Force | Out-Null
    Set-Content -LiteralPath ([System.IO.Path]::Combine($unownedState, 'keep.txt')) -Value 'keep'
    $refused = $false
    try {
        & "$repoRoot\scripts\windows\setup.ps1" `
            -TestMode `
            -StateRoot $unownedState `
            -CodexHome $codexHome `
            -NoPathUpdate | Out-Null
    } catch {
        $refused = $true
    }
    Assert-True $refused 'Setup did not refuse an unowned non-empty state directory.'

    $unownedProfileState = [System.IO.Path]::Combine($tempRoot, 'unowned-profile-state')
    Set-Content -LiteralPath $profilePath -Value '# user-owned profile' -Encoding Ascii
    $profileRefused = $false
    try {
        & "$repoRoot\scripts\windows\setup.ps1" `
            -TestMode `
            -StateRoot $unownedProfileState `
            -CodexHome $codexHome `
            -NoPathUpdate | Out-Null
    } catch {
        $profileRefused = $true
    }
    Assert-True $profileRefused 'Setup did not refuse an unowned Codex profile.'
    Assert-True (
        (Get-Content -LiteralPath $profilePath -Raw) -match 'user-owned'
    ) 'Setup changed an unowned Codex profile.'

    Write-Host 'Windows installer smoke test passed.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
