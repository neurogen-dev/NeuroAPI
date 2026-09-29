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

function New-DesktopTestCatalog {
    param([string]$Model)
    return @{ models = @(@{
        slug = $Model; display_name = 'Test model'; description = 'Description'; base_instructions = 'Instructions'
        supported_in_api = $true; supports_reasoning_summary_parameter = $true; support_verbosity = $false
        supports_parallel_tool_calls = $true; supports_search_tool = $false; use_responses_lite = $false
        priority = 0; context_window = 128000; max_context_window = 128000; auto_compact_token_limit = 100000
        effective_context_window_percent = 95; input_token_limit = 128000; output_token_limit = 16000
        supported_reasoning_levels = @(@{ effort = 'medium'; description = 'Medium' }); shell_type = 'shell_command'; visibility = 'list'
        model_messages = @{ instructions_template = 'Instructions' }; truncation_policy = @{ mode = 'tokens'; limit = 10000 }
        experimental_supported_tools = @(); input_modalities = @('text')
    }); default_model = $Model } | ConvertTo-Json -Depth 8 -Compress
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
    $profileBefore = Get-Content -LiteralPath $profilePath -Raw
    Assert-True ($profileBefore -match '(?m)^base_url = "https://codex.neuroapi.host/v1"\r?$') 'Wrong Codex base URL.'
    Assert-True ($profileBefore -match '(?m)^supports_websockets = true\r?$') 'Codex WebSocket support is missing.'
    Assert-True ($profileBefore -notmatch 'test-neuroapi-token|experimental_bearer_token|env_key|http_headers') 'Credential leaked into Codex configuration.'
    Assert-True ((Get-Content -LiteralPath $settingsPath -Raw) -notmatch 'test-neuroapi-token') 'Credential leaked into Claude configuration.'

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

    . (Join-Path $repoRoot 'scripts/windows/managed-catalog.ps1')
    $privateSnapshot = New-NeuroAPILaunchDirectory -StateRoot $stateRoot
    $snapshotAcl = Get-Acl -LiteralPath $privateSnapshot
    Assert-True $snapshotAcl.AreAccessRulesProtected 'Launch snapshot inherited a public ACL.'
    $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    foreach ($rule in $snapshotAcl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
        Assert-True ($rule.IdentityReference.Value -ceq $currentSid) 'Launch snapshot grants another account access.'
    }
    Remove-Item -LiteralPath $privateSnapshot -Force

    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    Assert-True ($settings.env.ANTHROPIC_BASE_URL -ceq 'https://claude.neuroapi.host') 'Wrong Claude base URL.'
    Assert-True (-not ($settings.env.PSObject.Properties.Name -contains 'ANTHROPIC_MODEL')) 'A bundled model must not override fresh catalog defaults.'
    Assert-True ($profileBefore -notmatch '(?m)^model =') 'Codex default must come from the fresh catalog.'
    foreach ($launcherFile in @('common.ps1', 'managed-catalog.ps1', 'launch-neuroapi.ps1')) {
        Assert-True (Test-Path -LiteralPath (Join-Path $stateRoot ('bin/' + $launcherFile))) 'Managed launcher dependency missing.'
    }
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
            & $pythonExecutable @pythonPrefix "$repoRoot/tests/static/profile_contract.py" $profilePath windows $helperPath $secretPath
            Assert-True ($LASTEXITCODE -eq 0) 'Generated Codex profile violates the profile contract.'
        }
    }

    & "$repoRoot\scripts\windows\setup.ps1" `
        -TestMode `
        -StateRoot $stateRoot `
        -CodexHome $codexHome `
        -NoPathUpdate | Out-Null

    Assert-True ((Get-Content -LiteralPath $profilePath -Raw) -ceq $profileBefore) 'Reinstall changed the generated Codex profile.'

    # A failed key rotation must restore every installer-owned file, including
    # the exact previous DPAPI ciphertext, even after the new key was written.
    $tracked = @($secretPath, $profilePath, $profileMarker, $settingsPath)
    foreach ($file in @('get-neuroapi-key.ps1', 'common.ps1', 'managed-catalog.ps1', 'launch-neuroapi.ps1',
        'codex-neuroapi.cmd', 'claude-neuroapi.cmd')) {
        $tracked += (Join-Path (Join-Path $stateRoot 'bin') $file)
    }
    $beforeHashes = @{}
    foreach ($path in $tracked) { $beforeHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
    $env:NEUROAPI_AGENTS_TEST_TOKEN = 'rotated-test-token'
    foreach ($failurePoint in @('claude-settings.json', 'api-key.dpapi')) {
        $env:NEUROAPI_AGENTS_TEST_FAIL_AFTER = $failurePoint
        $rotationFailed = $false
        $rotationError = ''
        try {
            & "$repoRoot\scripts\windows\setup.ps1" `
                -TestMode -StateRoot $stateRoot -CodexHome $codexHome -NoPathUpdate | Out-Null
        } catch {
            $rotationError = $_.Exception.Message
            $rotationFailed = $rotationError -match 'Simulated setup transaction failure'
        }
        Assert-True $rotationFailed "Injected failure after $failurePoint did not restore cleanly: $rotationError"
        foreach ($path in $tracked) {
            Assert-True ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ceq $beforeHashes[$path]) "Failed rotation changed $path."
        }
        $restoredKey = & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $helperPath -SecretPath $secretPath
        Assert-True ($restoredKey -ceq 'test-neuroapi-token') 'Failed rotation lost the previous DPAPI key.'
        $residue = @(Get-ChildItem -LiteralPath $stateRoot, $codexHome -Recurse -Force | Where-Object {
            $_.Name -match '^(setup-stage-)|\.(new|backup|discard)\.[a-f0-9]{32}$'
        })
        Assert-True ($residue.Count -eq 0) 'Failed rotation left stage or backup files.'
    }
    $env:NEUROAPI_AGENTS_TEST_FAIL_AFTER = $null
    & "$repoRoot\scripts\windows\setup.ps1" `
        -TestMode -StateRoot $stateRoot -CodexHome $codexHome -NoPathUpdate | Out-Null
    $rotatedKey = & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $helperPath -SecretPath $secretPath
    Assert-True ($rotatedKey -ceq 'rotated-test-token') 'Successful retry did not install the replacement key.'
    $env:NEUROAPI_AGENTS_TEST_TOKEN = $null

    $desktopCatalog = New-DesktopTestCatalog 'gpt-6-sol'
    & "$repoRoot\scripts\windows\setup.ps1" `
        -TestMode -StateRoot $stateRoot -CodexHome $codexHome -NoPathUpdate `
        -EnableCodexDesktop -DesktopCatalogJson $desktopCatalog | Out-Null
    $desktopConfigPath = Join-Path $codexHome 'config.toml'
    $desktopStatePath = Join-Path $stateRoot 'config/codex-desktop-state.json'
    $desktopCatalogPath = Join-Path $stateRoot 'config/codex-desktop-models.json'
    Assert-True (Test-Path -LiteralPath $desktopConfigPath) 'Desktop config was not created.'
    Assert-True (Test-Path -LiteralPath $desktopStatePath) 'Desktop ownership metadata is missing.'
    Assert-True (Test-Path -LiteralPath $desktopCatalogPath) 'Desktop model catalog is missing.'
    $desktopBefore = [IO.File]::ReadAllText($desktopConfigPath)
    Assert-True ($desktopBefore -match '(?m)^model = "gpt-6-sol"$') 'Entitled default model was not selected.'
    Assert-True ($desktopBefore -match 'https://codex.neuroapi.host/v1') 'Desktop URL is incorrect.'
    Assert-True ($desktopBefore -notmatch 'test-neuroapi-token') 'Desktop config contains a plaintext key.'
    & "$repoRoot\scripts\windows\setup.ps1" `
        -TestMode -StateRoot $stateRoot -CodexHome $codexHome -NoPathUpdate `
        -EnableCodexDesktop -DesktopCatalogJson $desktopCatalog | Out-Null
    Assert-True ([IO.File]::ReadAllText($desktopConfigPath) -ceq $desktopBefore) 'Desktop rerun changed a stable config.'

    $desktopKeyBefore = (Get-FileHash -LiteralPath $secretPath -Algorithm SHA256).Hash
    $emptyCatalogRefused = $false
    try {
        & "$repoRoot\scripts\windows\setup.ps1" `
            -TestMode -StateRoot $stateRoot -CodexHome $codexHome -NoPathUpdate `
            -EnableCodexDesktop -DesktopCatalogJson '{}' | Out-Null
    } catch { $emptyCatalogRefused = $true }
    Assert-True $emptyCatalogRefused 'Desktop setup accepted a key with no usable model catalog.'
    Assert-True ([IO.File]::ReadAllText($desktopConfigPath) -ceq $desktopBefore) 'Invalid catalog changed Desktop config.'
    Assert-True ((Get-FileHash -LiteralPath $secretPath -Algorithm SHA256).Hash -ceq $desktopKeyBefore) 'Invalid catalog changed protected key.'
    $env:NEUROAPI_AGENTS_TEST_TOKEN = 'attempted-rotation'
    $env:NEUROAPI_AGENTS_TEST_FAIL_AFTER = 'config.toml'
    $desktopFailed = $false
    try {
        & "$repoRoot\scripts\windows\setup.ps1" `
            -TestMode -StateRoot $stateRoot -CodexHome $codexHome -NoPathUpdate `
            -EnableCodexDesktop -DesktopCatalogJson $desktopCatalog | Out-Null
    } catch { $desktopFailed = $_.Exception.Message -match 'Simulated setup transaction failure' }
    Assert-True $desktopFailed 'Desktop rollback injection did not fail.'
    Assert-True ([IO.File]::ReadAllText($desktopConfigPath) -ceq $desktopBefore) 'Desktop rollback changed config.'
    Assert-True ((Get-FileHash -LiteralPath $secretPath -Algorithm SHA256).Hash -ceq $desktopKeyBefore) 'Desktop rollback changed protected key.'
    $env:NEUROAPI_AGENTS_TEST_FAIL_AFTER = $null
    $env:NEUROAPI_AGENTS_TEST_TOKEN = $null

    [IO.File]::AppendAllText($desktopConfigPath, "`n# user edit`n")
    $desktopUninstallRefused = $false
    try {
        & "$repoRoot\scripts\windows\uninstall.ps1" `
            -TestMode -StateRoot $stateRoot -CodexHome $codexHome -NoPathUpdate | Out-Null
    } catch { $desktopUninstallRefused = $_.Exception.Message -match 'changed after setup' }
    Assert-True $desktopUninstallRefused 'Uninstall overwrote a later user edit.'
    Assert-True (Test-Path -LiteralPath $secretPath) 'Uninstall removed the key while Desktop still depends on it.'
    [IO.File]::WriteAllText($desktopConfigPath, $desktopBefore, (New-Object Text.UTF8Encoding($false)))

    & "$repoRoot\scripts\windows\uninstall.ps1" `
        -TestMode `
        -StateRoot $stateRoot `
        -CodexHome $codexHome `
        -NoPathUpdate | Out-Null

    Assert-True (-not (Test-Path -LiteralPath $stateRoot)) 'Installer state remains after uninstall.'
    Assert-True (-not (Test-Path -LiteralPath $profilePath)) 'Codex profile remains after uninstall.'
    Assert-True (Test-Path -LiteralPath $sentinel) 'Uninstall removed an unrelated file.'

    $originalDesktop = "# existing user setup`nmodel = `"old-model`"`n[features]`nmulti_agent = true`n"
    [IO.File]::WriteAllText($desktopConfigPath, $originalDesktop, (New-Object Text.UTF8Encoding($false)))
    $fallbackCatalog = New-DesktopTestCatalog 'model-one'
    & "$repoRoot\scripts\windows\setup.ps1" `
        -TestMode -StateRoot $stateRoot -CodexHome $codexHome -NoPathUpdate `
        -EnableCodexDesktop -DesktopCatalogJson $fallbackCatalog | Out-Null
    $existingUpdated = [IO.File]::ReadAllText($desktopConfigPath)
    Assert-True ($existingUpdated -match '(?m)^model = "model-one"$') 'An unavailable gpt-6-sol was selected.'
    Assert-True ($existingUpdated -match '(?m)^multi_agent = true$') 'User feature was overwritten.'
    & "$repoRoot\scripts\windows\uninstall.ps1" `
        -TestMode -StateRoot $stateRoot -CodexHome $codexHome -NoPathUpdate | Out-Null
    Assert-True ([IO.File]::ReadAllText($desktopConfigPath) -ceq $originalDesktop) 'Uninstall did not restore the user config.'

    $conflict = "[model_providers.neuroapi_agents]`nname = `"Mine`"`n"
    [IO.File]::WriteAllText($desktopConfigPath, $conflict, (New-Object Text.UTF8Encoding($false)))
    $conflictRefused = $false
    try {
        & "$repoRoot\scripts\windows\setup.ps1" `
            -TestMode -StateRoot $stateRoot -CodexHome $codexHome -NoPathUpdate `
            -EnableCodexDesktop -DesktopCatalogJson $fallbackCatalog | Out-Null
    } catch { $conflictRefused = $true }
    Assert-True $conflictRefused 'Installer overwrote a user-owned provider.'
    Assert-True ([IO.File]::ReadAllText($desktopConfigPath) -ceq $conflict) 'Provider conflict changed user config.'
    Remove-Item -LiteralPath $desktopConfigPath -Force

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

    & (Join-Path $PSScriptRoot 'managed-catalog.ps1')
    Write-Host 'Windows installer smoke test passed.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
