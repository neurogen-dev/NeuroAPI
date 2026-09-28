Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True { param([bool]$Condition, [string]$Message) if (-not $Condition) { throw $Message } }

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $repoRoot 'scripts/windows/common.ps1')
. (Join-Path $repoRoot 'scripts/windows/managed-catalog.ps1')
$realCodexInstaller = ${function:Install-NeuroAPICodex}
$realClientExecutable = ${function:Get-NeuroAPIClientExecutable}
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('neuroapi-first-run-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    $current = Join-Path $tempRoot 'current.ps1'
    $old = Join-Path $tempRoot 'old.ps1'
    Set-Content -LiteralPath $current -Value "'codex-cli 0.158.0'" -Encoding Ascii
    Set-Content -LiteralPath $old -Value "'codex-cli 0.120.0'" -Encoding Ascii
    Assert-NeuroAPIClientReady -Client codex -Command $current
    $rejected = $false
    try { Assert-NeuroAPIClientReady -Client codex -Command $old } catch { $rejected = $_.Exception.Message -match '0.158.0' }
    Assert-True $rejected 'An obsolete client was accepted without an actionable version.'

    $script:KnownClients = @{ codex = $null; claude = $null }
    $script:Installs = @{ codex = 0; claude = 0 }
    function Get-NeuroAPIClientExecutable { param([string]$Client, [string]$StateRoot) return $script:KnownClients[$Client] }
    function Assert-NeuroAPIClientReady { param([string]$Client, [string]$Command) if ($Command -eq 'old') { throw 'Outdated client' }; if (-not $Command) { throw 'Missing client' } }
    function Install-NeuroAPICodex { param([string]$StateRoot) $script:Installs.codex++; $script:KnownClients.codex = 'new-codex' }
    function Install-NeuroAPIClaude { param([string]$StateRoot) $script:Installs.claude++; $script:KnownClients.claude = 'new-claude' }
    function Read-Host { param([string]$Prompt) return '' }

    $installed = @(Ensure-NeuroAPIClients -StateRoot $tempRoot)
    Assert-True ($installed.Count -eq 2 -and $script:Installs.codex -eq 1 -and $script:Installs.claude -eq 1) 'Both missing clients were not installed exactly once.'
    $again = @(Ensure-NeuroAPIClients -StateRoot $tempRoot)
    Assert-True ($again.Count -eq 0 -and $script:Installs.codex -eq 1 -and $script:Installs.claude -eq 1) 'Existing clients were modified on rerun.'
    $script:KnownClients.codex = 'old'
    $updated = @(Ensure-NeuroAPIClients -StateRoot $tempRoot)
    Assert-True ($updated.Count -eq 1 -and $updated[0] -eq 'codex' -and $script:Installs.codex -eq 2 -and $script:Installs.claude -eq 1) 'An old client was not replaced by an owned current copy.'

    $script:PathEntries = @('C:\preexisting')
    function Add-UserPathEntry { param([string]$Entry) if ($script:PathEntries -contains $Entry) { return $false }; $script:PathEntries += $Entry; return $true }
    function Remove-UserPathEntry { param([string]$Entry) $script:PathEntries = @($script:PathEntries | Where-Object { $_ -ne $Entry }) }
    Add-OwnedUserPathEntry -Entry 'C:\preexisting' -StateRoot $tempRoot
    Add-OwnedUserPathEntry -Entry 'C:\new' -StateRoot $tempRoot
    Add-OwnedUserPathEntry -Entry 'C:\new' -StateRoot $tempRoot
    Remove-OwnedUserPathEntries -StateRoot $tempRoot
    Assert-True ($script:PathEntries.Count -eq 1 -and $script:PathEntries[0] -eq 'C:\preexisting') 'Uninstall removed a PATH entry it did not add.'

    $secure = ConvertTo-SecureString -String 'dummy-secret' -AsPlainText -Force
    $script:CatalogStatus = 200
    $script:CatalogCalls = 0
    $script:CatalogBodies = @{
        codex = (@{ models = @(@{
            slug = 'gpt-6-sol'; display_name = 'GPT-6 Sol'; description = 'Test'; base_instructions = 'Test'
            supported_in_api = $true; supports_reasoning_summary_parameter = $true; support_verbosity = $false
            supports_parallel_tool_calls = $true; supports_search_tool = $false; use_responses_lite = $false
            priority = 0; context_window = 128000; max_context_window = 128000; auto_compact_token_limit = 100000
            effective_context_window_percent = 95; input_token_limit = 128000; output_token_limit = 16000
            supported_reasoning_levels = @(@{ effort = 'medium'; description = 'Medium' }); shell_type = 'shell_command'; visibility = 'list'
            model_messages = @{ instructions_template = 'Test' }; truncation_policy = @{ mode = 'tokens'; limit = 10000 }
            experimental_supported_tools = @(); input_modalities = @('text')
        }); default_model = 'gpt-6-sol' } | ConvertTo-Json -Depth 8 -Compress)
        claude = (@{
            model = 'claude-opus-5-5'; availableModels = @('claude-opus-5-5'); enforceAvailableModels = $true; fallbackModel = @()
            modelPicker = @{ options = @(@{ model = 'claude-opus-5-5'; label = 'Opus 5.5' }); replaceBuiltInOptions = $true }
            env = @{ ANTHROPIC_DEFAULT_OPUS_MODEL = 'claude-opus-5-5' }
        } | ConvertTo-Json -Depth 8 -Compress)
    }
    function Get-NeuroAPIHTTPSContent {
        param([string]$Url, [string[]]$AllowedHosts, [long]$MaxBytes, [string]$Bearer, [string]$OutputPath, [int]$TimeoutSeconds)
        if ($Bearer -cne 'dummy-secret') { throw 'Wrong test credential' }
        $script:CatalogCalls++
        $client = if ($Url -like '*/codex/*') { 'codex' } else { 'claude' }
        return [pscustomobject]@{ Status = $script:CatalogStatus; Bytes = [Text.Encoding]::UTF8.GetBytes($script:CatalogBodies[$client]) }
    }
    Assert-NeuroAPIKeyCatalogs -SecureKey $secure
    Assert-True ($script:CatalogCalls -eq 2) 'Preflight did not check both catalogs.'
    $validCodexBody = $script:CatalogBodies.codex
    $script:CatalogBodies.codex = '{}'
    $message = ''
    try { Assert-NeuroAPIKeyCatalogs -SecureKey $secure } catch { $message = $_.Exception.Message }
    Assert-True ($message -match 'некорректный' -and $message -notmatch 'dummy-secret') 'A 200 response with an empty Codex catalog was accepted.'
    $script:CatalogBodies.codex = $validCodexBody
    $script:CatalogBodies.claude = '{}'
    $message = ''
    try { Assert-NeuroAPIKeyCatalogs -SecureKey $secure } catch { $message = $_.Exception.Message }
    Assert-True ($message -match 'некорректный' -and $message -notmatch 'dummy-secret') 'A 200 response with an empty catalog was accepted.'
    $script:CatalogBodies.claude = (@{
        model = 'claude-opus-5-5'; availableModels = @('claude-opus-5-5'); enforceAvailableModels = $true; fallbackModel = @()
        modelPicker = @{ options = @(@{ model = 'claude-opus-5-5' }); replaceBuiltInOptions = $true }
        env = @{}
    } | ConvertTo-Json -Depth 8 -Compress)
    Assert-NeuroAPIKeyCatalogs -SecureKey $secure
    $script:CatalogStatus = 401
    $message = ''
    try { Assert-NeuroAPIKeyCatalogs -SecureKey $secure } catch { $message = $_.Exception.Message }
    Assert-True ($message -match 'отклонен' -and $message -notmatch 'dummy-secret') 'Invalid key did not fail safely.'
    $script:CatalogStatus = 503
    $message = ''
    try { Assert-NeuroAPIKeyCatalogs -SecureKey $secure } catch { $message = $_.Exception.Message }
    Assert-True ($message -match 'недоступен' -and $message -notmatch 'dummy-secret') 'Unavailable catalog did not fail safely.'
    $secure.Dispose()

    # Exercise native bundle extraction with a tiny local ZIP. The test never
    # runs a vendor installer or downloads a binary.
    Set-Item function:Install-NeuroAPICodex $realCodexInstaller
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $bundleRoot = Join-Path $tempRoot 'bundle-source'
    $installRoot = Join-Path $tempRoot 'bundle-install'
    New-Item -ItemType Directory -Path (Join-Path $bundleRoot 'codex-resources') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $installRoot 'bin') -Force | Out-Null
    $assetName = 'codex-x86_64-pc-windows-msvc.exe.zip'
    Set-Content -LiteralPath (Join-Path $bundleRoot $assetName.Replace('.zip', '')) -Value 'test executable' -Encoding Ascii
    Set-Content -LiteralPath (Join-Path $bundleRoot 'codex-resources/manifest.json') -Value '{}' -Encoding Ascii
    $bundleZip = Join-Path $tempRoot 'bundle.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($bundleRoot, $bundleZip)
    $script:BundleZip = $bundleZip
    $script:BundleDigest = (Get-FileHash -LiteralPath $bundleZip -Algorithm SHA256).Hash.ToLowerInvariant()
    function Get-NeuroAPIHTTPSContent {
        param([string]$Url, [string[]]$AllowedHosts, [long]$MaxBytes, [string]$Bearer, [string]$OutputPath, [int]$TimeoutSeconds)
        if ($Url -like 'https://api.github.com/*') {
            $asset = @{ name = 'codex-x86_64-pc-windows-msvc.exe.zip'; size = (Get-Item $script:BundleZip).Length; digest = ('sha256:' + $script:BundleDigest); browser_download_url = 'https://github.com/openai/codex/releases/download/rust-v0.158.0/codex-x86_64-pc-windows-msvc.exe.zip' }
            return [pscustomobject]@{ Status = 200; Bytes = [Text.Encoding]::UTF8.GetBytes((@{ assets = @($asset) } | ConvertTo-Json -Depth 5)) }
        }
        Copy-Item -LiteralPath $script:BundleZip -Destination $OutputPath
        return [pscustomobject]@{ Status = 200; Bytes = $null }
    }
    Install-NeuroAPICodex -StateRoot $installRoot
    Assert-True (Test-Path -LiteralPath (Join-Path $installRoot 'native-codex/codex.exe')) 'Native Codex binary was not extracted.'
    Assert-True (Test-Path -LiteralPath (Join-Path $installRoot 'native-codex/codex-resources/manifest.json')) 'Codex support files were not extracted.'
    Assert-True (Test-Path -LiteralPath (Join-Path $installRoot 'bin/codex.cmd')) 'Codex command launcher was not created.'
    $nativePath = Join-Path $installRoot 'native-codex/codex.exe'
    $beforeUpdate = Get-Content -LiteralPath $nativePath -Raw
    $script:BundleDigest = ('0' * 64)
    $updateRejected = $false
    try { Install-NeuroAPICodex -StateRoot $installRoot } catch { $updateRejected = $true }
    Assert-True ($updateRejected -and (Get-Content -LiteralPath $nativePath -Raw) -ceq $beforeUpdate) 'A failed update changed the installed Codex bundle.'
    $script:BundleDigest = (Get-FileHash -LiteralPath $bundleZip -Algorithm SHA256).Hash.ToLowerInvariant()
    $wrapperPath = Join-Path $installRoot 'bin/codex.cmd'
    $wrapperBefore = Get-Content -LiteralPath $wrapperPath -Raw
    Set-Content -LiteralPath $wrapperPath -Value 'other launcher' -Encoding Ascii
    $conflictRejected = $false
    try { Install-NeuroAPICodex -StateRoot $installRoot } catch { $conflictRejected = $true }
    Assert-True ($conflictRejected -and (Get-Content -LiteralPath $nativePath -Raw) -ceq $beforeUpdate) 'A launcher conflict did not restore the previous Codex bundle.'
    Assert-True ((Get-Content -LiteralPath $wrapperPath -Raw) -match 'other launcher') 'A launcher conflict overwrote the existing file.'
    Write-Utf8NoBom -Path $wrapperPath -Content $wrapperBefore
    Set-Content -LiteralPath (Join-Path $bundleRoot $assetName.Replace('.zip', '')) -Value 'updated executable' -Encoding Ascii
    Remove-Item -LiteralPath $bundleZip
    [IO.Compression.ZipFile]::CreateFromDirectory($bundleRoot, $bundleZip)
    $script:BundleDigest = (Get-FileHash -LiteralPath $bundleZip -Algorithm SHA256).Hash.ToLowerInvariant()
    Install-NeuroAPICodex -StateRoot $installRoot
    Assert-True ((Get-Content -LiteralPath $nativePath -Raw) -match 'updated executable') 'A verified owned Codex bundle was not updated.'
    Assert-True (@(Get-ChildItem -LiteralPath $installRoot -Filter 'codex-backup-*').Count -eq 0) 'Successful update left an obsolete backup.'
    Set-Item function:Get-NeuroAPIClientExecutable $realClientExecutable
    function Get-Command { param([string]$Name, $CommandType, $ErrorAction) return $null }
    $resolved = Get-NeuroAPIClientExecutable -Client codex -StateRoot $installRoot
    Remove-Item function:Get-Command
    Assert-True ($resolved -eq (Join-Path $installRoot 'native-codex/codex.exe')) 'Managed Codex must use the native binary, not the CMD wrapper.'
    Write-Host 'Windows first-run tests passed.'
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
