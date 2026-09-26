# These deterministic tests run on PowerShell 5.1 (Windows) and pwsh (other OS).
# Credential/network/process seams are mocked; no real keys or provider calls.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $repoRoot 'scripts/windows/common.ps1')
. (Join-Path $repoRoot 'scripts/windows/managed-catalog.ps1')

function Assert-Catalog {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Assert-CatalogFailure {
    param([scriptblock]$Action)
    $failed = $false
    try { & $Action | Out-Null } catch {
        $failed = $true
        Assert-Catalog ($_.Exception.Message -notmatch 'test-neuroapi-token|private-provider-body') 'Error exposed sensitive data.'
    }
    Assert-Catalog $failed 'Expected fail-closed rejection.'
}
function New-TestCodexCatalog {
    param([string]$Id)
    return @{ models = @(@{
        slug = $Id; display_name = 'Test model'; description = 'Description'; base_instructions = 'Test instructions'
        supported_in_api = $true; supports_reasoning_summary_parameter = $true; support_verbosity = $false
        supports_parallel_tool_calls = $true; supports_search_tool = $false; use_responses_lite = $false
        priority = 0; context_window = 128000; max_context_window = 128000; auto_compact_token_limit = 100000
        effective_context_window_percent = 95; input_token_limit = 128000; output_token_limit = 16000
        supported_reasoning_levels = @(@{ effort = 'medium'; description = 'Medium' }); shell_type = 'shell_command'; visibility = 'list'
        model_messages = @{ instructions_template = 'Instructions' }; truncation_policy = @{ mode = 'tokens'; limit = 10000 }
        experimental_supported_tools = @(); input_modalities = @('text')
    }); default_model = $Id } | ConvertTo-Json -Depth 8 -Compress
}
function New-TestClaudeCatalog {
    return @{
        model = 'claude-opus-5-5'; availableModels = @('claude-opus-5-5', 'claude-sonnet-5', 'claude-haiku-4-5', 'claude-opus-5', 'claude-opus-4.8')
        enforceAvailableModels = $true; fallbackModel = @()
        modelPicker = @{ options = @(@{ model = 'claude-opus-5-5'; label = 'Opus 5.5' }, @{ model = 'claude-sonnet-5'; label = 'Sonnet 5' }, @{ model = 'claude-haiku-4-5' }); replaceBuiltInOptions = $true }
        env = @{ ANTHROPIC_DEFAULT_OPUS_MODEL = 'claude-opus-5-5'; ANTHROPIC_DEFAULT_SONNET_MODEL = 'claude-sonnet-5'; ANTHROPIC_DEFAULT_HAIKU_MODEL = 'claude-haiku-4-5' }
    } | ConvertTo-Json -Depth 8 -Compress
}

$codex = ConvertFrom-NeuroAPICatalog codex (New-TestCodexCatalog 'model-one') ''
Assert-Catalog ($codex.DefaultModel -ceq 'model-one') 'Default model was not preserved.'
Assert-Catalog ($codex.Content.models[0].base_instructions -ceq 'Test instructions') 'Full ModelInfo was lost.'
$claude = ConvertFrom-NeuroAPICatalog claude (New-TestClaudeCatalog) 'local-helper'
Assert-Catalog ($claude.apiKeyHelper -ceq 'local-helper') 'Server replaced credential command.'
Assert-Catalog (-not $claude.Contains('hooks')) 'Server hooks were copied.'
Assert-Catalog ($claude.env.ANTHROPIC_CUSTOM_HEADERS -ceq '' -and $claude.env.ANTHROPIC_AUTH_TOKEN -ceq '') 'Merged settings can override credentials.'
Assert-Catalog ($claude.env.ANTHROPIC_MODEL -ceq $claude.model) 'Merged model override can bypass default.'
Assert-Catalog (-not $claude.env.Contains('UNSAFE_ENV')) 'Unreviewed environment was copied.'
Assert-Catalog (-not $claude.env.Contains('ANTHROPIC_DEFAULT_FABLE_MODEL')) 'Missing Fable was invented.'
Assert-Catalog ($claude.availableModels.Count -eq 5 -and $claude.modelPicker.options.Count -eq 3) 'Compatibility aliases must remain available but hidden.'
Assert-Catalog ($claude.fallbackModel.Count -eq 0) 'Inherited fallback was not disabled.'
foreach ($bad in @('{', '{}', '{"models":[],"default_model":"model-one"}', '{"models":[{"slug":"model-one","display_name":"one"}],"default_model":"missing"}', '{"models":[{"slug":"bad model","display_name":"one"}],"default_model":"bad model"}')) {
    Assert-CatalogFailure { ConvertFrom-NeuroAPICatalog codex $bad '' }
}
foreach ($mutation in @(
    { param($x) $x.models[0].visibility = 'hide' },
    { param($x) $x.models[0].supported_in_api = $false },
    { param($x) $x.models[0].PSObject.Properties.Remove('context_window') },
    { param($x) $x.models[0].context_window = -1 },
    { param($x) $x.models[0].supported_reasoning_levels = @(@{ effort = 'wrong'; description = '' }) },
    { param($x) $x.models[0] | Add-Member -NotePropertyName hooks -NotePropertyValue @{} }
)) {
    $payload = New-TestCodexCatalog 'model-one' | ConvertFrom-Json
    & $mutation $payload
    $invalid = $payload | ConvertTo-Json -Depth 8 -Compress
    Assert-CatalogFailure { ConvertFrom-NeuroAPICatalog codex $invalid '' }
}
foreach ($mutation in @(
    { param($x) $x | Add-Member -NotePropertyName hooks -NotePropertyValue @{ dangerous = 'ignore' } },
    { param($x) $x | Add-Member -NotePropertyName apiKeyHelper -NotePropertyValue 'untrusted command' },
    { param($x) $x.env | Add-Member -NotePropertyName UNSAFE_ENV -NotePropertyValue 'ignore' },
    { param($x) $x.availableModels = @() },
    { param($x) $x.enforceAvailableModels = $false },
    { param($x) $x.model = 'not-allowed' },
    { param($x) $x.model = 'claude-opus-5' },
    { param($x) $x.fallbackModel = @('not-allowed') },
    { param($x) $x.modelPicker.options[0].model = 'not-allowed' },
    { param($x) $x.env.ANTHROPIC_DEFAULT_HAIKU_MODEL = 'claude-sonnet-5' },
    { param($x) $x.env.ANTHROPIC_DEFAULT_HAIKU_MODEL = '' }
)) {
    $payload = New-TestClaudeCatalog | ConvertFrom-Json
    & $mutation $payload
    $invalid = $payload | ConvertTo-Json -Depth 8 -Compress
    Assert-CatalogFailure { ConvertFrom-NeuroAPICatalog claude $invalid 'local-helper' }
}

Add-Type -AssemblyName System.Net.Http
if (-not ('NeuroAPITestHttpHandler' -as [type])) {
    $references = @([Net.Http.HttpClient].Assembly.Location)
    if ($PSVersionTable.PSEdition -eq 'Core') { $references += [Net.HttpStatusCode].Assembly.Location }
    Add-Type -ReferencedAssemblies $references -TypeDefinition @'
using System;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
public sealed class NeuroAPITestHttpHandler : HttpMessageHandler {
    public int Status = 200;
    public string Body = "{}";
    public string Uri;
    public string Authorization;
    public bool Fail;
    public bool MisleadingLength;
    public int Calls;
    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken token) {
        Calls++;
        Uri = request.RequestUri.ToString();
        Authorization = request.Headers.Authorization.ToString();
        if (Fail) throw new HttpRequestException("private-provider-body test-neuroapi-token");
        var response = new HttpResponseMessage((HttpStatusCode)Status);
        response.Content = new StringContent(Body);
        if (MisleadingLength) response.Content.Headers.ContentLength = 1;
        response.Headers.Location = new Uri("https://invalid.example/redirect");
        return Task.FromResult(response);
    }
}
'@
}
$originalClientFactory = ${function:New-NeuroAPICatalogClient}
function New-NeuroAPICatalogClient { return New-Object Net.Http.HttpClient($script:mockHttp) }
function Read-NeuroAPIProtectedCredential { param([string]$SecretPath) return 'test-neuroapi-token' }
foreach ($client in @('codex', 'claude')) {
    $script:mockHttp = New-Object NeuroAPITestHttpHandler
    $script:mockHttp.Body = New-TestCodexCatalog 'model-network'
    $wire = Get-NeuroAPICatalogJson $client 'unused-secret-path'
    Assert-Catalog ($wire -ceq $script:mockHttp.Body) 'Catalog response changed.'
    Assert-Catalog ($script:mockHttp.Authorization -ceq 'Bearer test-neuroapi-token') 'Authorization missing.'
    $expected = if ($client -eq 'codex') { 'https://neuroapi.host/v1/codex/models' } else { 'https://neuroapi.host/v1/claude-code/client-settings' }
    Assert-Catalog ($script:mockHttp.Uri -ceq $expected) 'Wrong catalog endpoint.'
}
foreach ($status in @(301, 302, 401, 403, 429, 503)) {
    $script:mockHttp = New-Object NeuroAPITestHttpHandler
    $script:mockHttp.Status = $status
    $script:mockHttp.Body = 'private-provider-body test-neuroapi-token'
    Assert-CatalogFailure { Get-NeuroAPICatalogJson codex 'unused' }
    Assert-Catalog ($script:mockHttp.Calls -eq 1) 'Redirect or retry occurred.'
}
$script:mockHttp = New-Object NeuroAPITestHttpHandler
$script:mockHttp.Fail = $true
Assert-CatalogFailure { Get-NeuroAPICatalogJson codex 'unused' }
$script:mockHttp = New-Object NeuroAPITestHttpHandler
$script:mockHttp.Body = 'x' * (2 * 1024 * 1024 + 1)
Assert-CatalogFailure { Get-NeuroAPICatalogJson codex 'unused' }
$script:mockHttp = New-Object NeuroAPITestHttpHandler
$script:mockHttp.Body = 'x' * (2 * 1024 * 1024 + 1)
$script:mockHttp.MisleadingLength = $true
Assert-CatalogFailure { Get-NeuroAPICatalogJson codex 'unused' }
foreach ($echoBody in @('{"display_name":"test-neuroapi-token"}', '{"display_name":"\u0074est-neuroapi-token"}', '{"\u0074est-neuroapi-token":"value"}')) {
    $script:mockHttp = New-Object NeuroAPITestHttpHandler
    $script:mockHttp.Body = $echoBody
    Assert-CatalogFailure { Get-NeuroAPICatalogJson codex 'unused' }
}
# Ensure the actual factory (not the mocked handler) disables redirects/cookies.
$factorySource = $originalClientFactory.ToString()
Assert-Catalog ($factorySource.Contains('$handler.AllowAutoRedirect = $false')) 'Redirects are enabled.'
Assert-Catalog ($factorySource.Contains('$handler.UseCookies = $false')) 'Cookies are enabled.'

# Exercise the actual version gate without installing or launching a client.
function Get-TestClientVersion {
    $global:LASTEXITCODE = $script:versionExit
    $script:versionText
}
foreach ($versionCase in @(
    @{ Client = 'codex'; Text = 'codex-cli 0.147.0'; Valid = $true },
    @{ Client = 'codex'; Text = 'codex-cli 0.146.9'; Valid = $false },
    @{ Client = 'codex'; Text = 'codex-cli 0.147.0-alpha.1'; Valid = $false },
    @{ Client = 'claude'; Text = '2.1.280 (Claude Code)'; Valid = $true },
    @{ Client = 'claude'; Text = '2.1.279 (Claude Code)'; Valid = $false },
    @{ Client = 'claude'; Text = 'unknown'; Valid = $false }
)) {
    $script:versionExit = 0
    $script:versionText = $versionCase.Text
    if ($versionCase.Valid) {
        Assert-NeuroAPIClientVersion -Client $versionCase.Client -Command 'Get-TestClientVersion'
    } else {
        Assert-CatalogFailure { Assert-NeuroAPIClientVersion -Client $versionCase.Client -Command 'Get-TestClientVersion' }
    }
}
$script:versionExit = 1
$script:versionText = 'codex-cli 0.147.0'
Assert-CatalogFailure { Assert-NeuroAPIClientVersion -Client codex -Command 'Get-TestClientVersion' }

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('neuroapi-managed-test-' + [Guid]::NewGuid().ToString('N'))
$savedFast = $env:ANTHROPIC_SMALL_FAST_MODEL
$savedFable = $env:ANTHROPIC_DEFAULT_FABLE_MODEL
$savedHostProvider = $env:CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST
$savedCustomHeaders = $env:ANTHROPIC_CUSTOM_HEADERS
$savedAwsProvider = $env:CLAUDE_CODE_USE_ANTHROPIC_AWS
$savedToolFlag = $env:CLAUDE_CODE_USE_TEST_TOOL
try {
    Ensure-Directory $tempRoot
    Write-OwnerMarker (Get-StateMarkerPath $tempRoot)
    # ACL/DPAPI require native Windows; test their integration in smoke.ps1.
    function Set-NeuroAPIPrivateDirectory { param([string]$Path) }
    function Get-NeuroAPIClientCommand { param([string]$Client) return 'mock-client' }
    function Assert-NeuroAPIClientVersion { param([string]$Client, [string]$Command) }
    $script:fetchCount = 0
    $script:childCount = 0
    $script:snapshots = @()
    $script:catalogJson = New-TestCodexCatalog 'model-first'
    function Get-NeuroAPICatalogJson { param([string]$Client, [string]$SecretPath) $script:fetchCount++; return $script:catalogJson }
    function Invoke-NeuroAPIChild {
        param([string]$Command, [string[]]$Arguments)
        $script:childCount++
        Assert-Catalog (($Arguments -join ' ') -notmatch 'test-neuroapi-token') 'Token leaked to argv.'
        if ($Arguments[0] -eq '--profile') {
            Assert-Catalog ($Arguments[1] -ceq 'neuroapi-host') 'Named profile lost.'
            $entry = $Arguments[3].Substring('model_catalog_json='.Length)
            $script:snapshots += $entry
            $catalogFile = Get-Content -LiteralPath $entry -Raw | ConvertFrom-Json
            Assert-Catalog ($catalogFile.models[0].slug -ceq $script:expectedModel) 'Catalog was stale.'
            Assert-Catalog ($Arguments[5] -ceq ("model='" + $script:expectedModel + "'")) 'Default model absent.'
            Assert-Catalog ($Arguments[6] -ceq '--model' -and $Arguments[7] -ceq 'deliberate-model') 'User flags changed.'
            Assert-Catalog ($Arguments[8] -ceq 'prompt with spaces') 'Prompt argument split.'
        } else {
            $entry = $Arguments[1]
            $script:snapshots += $entry
            $settings = Get-Content -LiteralPath $entry -Raw | ConvertFrom-Json
            Assert-Catalog ($settings.apiKeyHelper -match 'get-neuroapi-key.ps1') 'Local helper absent.'
            Assert-Catalog ($settings.model -ceq 'claude-opus-5-5') 'Managed model missing.'
            Assert-Catalog ($settings.env.ANTHROPIC_CUSTOM_HEADERS -ceq '' -and $settings.env.CLAUDE_CODE_USE_ANTHROPIC_AWS -ceq '') 'Merged settings can override endpoint or auth.'
            Assert-Catalog ($settings.env.ANTHROPIC_MODEL -ceq 'claude-opus-5-5') 'Merged settings can override model.'
            Assert-Catalog ([string]::IsNullOrEmpty($env:ANTHROPIC_CUSTOM_HEADERS) -and [string]::IsNullOrEmpty($env:CLAUDE_CODE_USE_ANTHROPIC_AWS)) 'Inherited auth/provider override survived.'
            Assert-Catalog ($env:CLAUDE_CODE_USE_TEST_TOOL -ceq 'keep') 'Unrelated tool switch was cleared.'
            Assert-Catalog ([string]::IsNullOrEmpty($env:ANTHROPIC_SMALL_FAST_MODEL)) 'Inherited fast model overrides catalog.'
            Assert-Catalog ([string]::IsNullOrEmpty($env:ANTHROPIC_DEFAULT_FABLE_MODEL)) 'Missing family inherited.'
            Assert-Catalog ($env:ANTHROPIC_DEFAULT_HAIKU_MODEL -ceq 'claude-haiku-4-5') 'Concrete family missing.'
            Assert-Catalog ($env:ANTHROPIC_BASE_URL -ceq 'https://neuroapi.host/v1/claude-code') 'Claude endpoint missing.'
        }
        $script:NeuroAPIChildExitCode = 37
    }
    foreach ($model in @('model-first', 'model-second')) {
        $script:catalogJson = New-TestCodexCatalog $model
        $script:expectedModel = $model
        Invoke-NeuroAPIManagedClient codex $tempRoot @('--model', 'deliberate-model', 'prompt with spaces')
        Assert-Catalog ($script:NeuroAPIChildExitCode -eq 37) 'Child exit code changed.'
    }
    Assert-Catalog ($script:fetchCount -eq 2 -and $script:childCount -eq 2) 'Every launch must refresh.'
    Assert-Catalog ($script:snapshots[0] -cne $script:snapshots[1]) 'Concurrent launches share a mutable snapshot.'
    $script:catalogJson = '{invalid}'
    Assert-CatalogFailure { Invoke-NeuroAPIManagedClient codex $tempRoot @() }
    Assert-Catalog ($script:childCount -eq 2) 'Malformed catalog launched child.'
    $script:catalogJson = New-TestClaudeCatalog
    foreach ($hostManagedValue in @('1', 'true', 'yes', 'on', ' true ', ' YES ', 'On')) {
        $env:CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST = $hostManagedValue
        $beforeHostBlock = $script:fetchCount
        Assert-CatalogFailure { Invoke-NeuroAPIManagedClient claude $tempRoot @() }
        Assert-Catalog ($script:fetchCount -eq $beforeHostBlock) 'Host-managed policy was bypassed.'
    }
    $env:CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST = $null
    $env:ANTHROPIC_CUSTOM_HEADERS = 'Authorization: foreign-value'
    $env:CLAUDE_CODE_USE_ANTHROPIC_AWS = '1'
    $env:CLAUDE_CODE_USE_TEST_TOOL = 'keep'
    $env:ANTHROPIC_SMALL_FAST_MODEL = 'old-fast-model'
    $env:ANTHROPIC_DEFAULT_FABLE_MODEL = 'old-fable'
    Invoke-NeuroAPIManagedClient claude $tempRoot @('--print', 'hello')
    Assert-Catalog ($env:ANTHROPIC_SMALL_FAST_MODEL -ceq 'old-fast-model') 'Parent environment changed.'
    Assert-Catalog ($env:ANTHROPIC_DEFAULT_FABLE_MODEL -ceq 'old-fable') 'Parent family changed.'
    # Exercise the actual launcher wrapper in an isolated child host: arbitrary
    # flags must remain data and the command's exit code must survive the wrapper.
    $wrapperRoot = Join-Path $tempRoot 'wrapper'
    $wrapperBin = Join-Path $wrapperRoot 'bin'
    Ensure-Directory $wrapperBin
    Copy-Item (Join-Path $repoRoot 'scripts/windows/launch-neuroapi.ps1') (Join-Path $wrapperBin 'launch-neuroapi.ps1')
    Write-Utf8NoBom (Join-Path $wrapperBin 'common.ps1') ''
    $mockLibrary = @'
function Invoke-NeuroAPIManagedClient {
    param([string]$Client, [string]$StateRoot, [string[]]$ClientArguments)
    [IO.File]::WriteAllText((Join-Path $StateRoot 'args.json'), (@{client=$Client;arguments=@($ClientArguments)} | ConvertTo-Json))
    $script:NeuroAPIChildExitCode = 37
}
'@
    Write-Utf8NoBom (Join-Path $wrapperBin 'managed-catalog.ps1') $mockLibrary
    $hostExecutable = (Get-Process -Id $PID).Path
    & $hostExecutable -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $wrapperBin 'launch-neuroapi.ps1') codex --model 'model-explicit' 'prompt with spaces'
    Assert-Catalog ($LASTEXITCODE -eq 37) 'Launcher did not forward the exit code.'
    $forwarded = Get-Content (Join-Path $wrapperRoot 'args.json') -Raw | ConvertFrom-Json
    Assert-Catalog ($forwarded.client -ceq 'codex' -and $forwarded.arguments.Count -eq 3) 'Launcher consumed a client flag.'
    Assert-Catalog ($forwarded.arguments[0] -ceq '--model' -and $forwarded.arguments[2] -ceq 'prompt with spaces') 'Launcher changed arguments.'
    Remove-Item -LiteralPath $wrapperRoot -Recurse -Force
    foreach ($snapshot in $script:snapshots) { Assert-Catalog (-not (Test-Path -LiteralPath $snapshot)) 'Launch snapshot was retained.' }
    Assert-Catalog (@(Get-ChildItem -LiteralPath $tempRoot -Directory).Count -eq 0) 'Launch directory was retained.'
} finally {
    $env:ANTHROPIC_SMALL_FAST_MODEL = $savedFast
    $env:ANTHROPIC_DEFAULT_FABLE_MODEL = $savedFable
    $env:CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST = $savedHostProvider
    $env:ANTHROPIC_CUSTOM_HEADERS = $savedCustomHeaders
    $env:CLAUDE_CODE_USE_ANTHROPIC_AWS = $savedAwsProvider
    $env:CLAUDE_CODE_USE_TEST_TOOL = $savedToolFlag
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
$global:LASTEXITCODE = 0
Write-Host 'Windows managed catalog mock tests passed (native DPAPI/ACL require Windows smoke).'
