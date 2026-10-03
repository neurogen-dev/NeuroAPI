Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $repoRoot 'scripts/windows/common.ps1')
. (Join-Path $repoRoot 'scripts/windows/managed-catalog.ps1')
. (Join-Path $repoRoot 'scripts/windows/desktop-config.ps1')

function Assert-Desktop {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Assert-DesktopFailure {
    param([scriptblock]$Action)
    $failed = $false
    try { & $Action | Out-Null } catch { $failed = $true }
    Assert-Desktop $failed 'Expected a fail-closed desktop configuration error.'
}

$options = @{
    HelperPath = 'C:\Users\Admin\AppData\Local\NeuroAPIAgents\bin\get-neuroapi-key.ps1'
    SecretPath = 'C:\Users\Admin\AppData\Local\NeuroAPIAgents\secret\api-key.dpapi'
    CatalogPath = 'C:\Users\Admin\AppData\Local\NeuroAPIAgents\config\codex-desktop-models.json'
    DefaultModel = 'gpt-6-sol'
}
$fresh = New-NeuroAPIDesktopConfig -Original '' @options
Assert-Desktop ($fresh -match '(?m)^model_provider = "neuroapi_agents"$') 'Fresh config has no provider.'
Assert-Desktop ($fresh -match '(?m)^web_search = "live"$') 'Fresh config has no hosted search.'
Assert-Desktop ($fresh -match '(?m)^remote_plugin = false$') 'Fresh config enables remote plugin sync.'
Assert-Desktop ($fresh -match '(?m)^model = "gpt-6-sol"$') 'Fresh config has no supported default.'
Assert-Desktop ($fresh -match '(?m)^base_url = "https://codex.neuroapi.host/v1"$') 'Desktop subdomain is wrong.'
Assert-Desktop ($fresh -match '(?m)^supports_websockets = false$') 'Unproven WebSocket path was enabled.'
Assert-Desktop ($fresh -notmatch 'sk-|experimental_bearer_token') 'A token was embedded in desktop config.'
Assert-Desktop ($fresh -match '# BEGIN NEUROAPI CODEX DESKTOP' -and $fresh -match '# END NEUROAPI CODEX DESKTOP') 'Ownership markers missing.'

$existing = @'
# User comment
model = "old-model" # keep elsewhere
model_provider = "other"
web_search = "cached"
[features]
plugins = true
remote_plugin = true # preserve comment
multi_agent = true
[mcp_servers.demo]
url = "https://example.test/mcp"
'@
$updated = New-NeuroAPIDesktopConfig -Original $existing @options
Assert-Desktop ($updated -match '(?m)^web_search = "live"$') 'Hosted search was not enabled.'
Assert-Desktop ($updated -match '(?m)^remote_plugin = false # preserve comment$') 'Remote plugin sync was not disabled.'
Assert-Desktop ($updated -match '(?m)^plugins = true$') 'Local plugins were disabled.'
Assert-Desktop (([regex]::Matches($updated, '(?m)^\[features\]$')).Count -eq 1) 'Features table was duplicated.'

Assert-Desktop ($updated -match '(?m)^multi_agent = true$') 'User feature was changed.'
Assert-Desktop ($updated -match '(?m)^url = "https://example.test/mcp"$') 'User MCP was changed.'
Assert-Desktop (([regex]::Matches($updated, '(?m)^model_provider\s*=')).Count -eq 1) 'Provider root key was duplicated.'
Assert-Desktop (([regex]::Matches($updated, '(?m)^model\s*=')).Count -eq 1) 'Model root key was duplicated.'
Assert-Desktop ($updated -match '(?s)^.*model_catalog_json = .*\[features\]') 'Catalog root key landed inside a table.'

Assert-DesktopFailure { New-NeuroAPIDesktopConfig -Original "[model_providers.neuroapi_agents]`nname = 'mine'" @options }
Assert-DesktopFailure { New-NeuroAPIDesktopConfig -Original '[model_providers."neuroapi_agents"]' @options }
$literal = New-NeuroAPIDesktopConfig -Original "model = 'literal'" @options
Assert-Desktop ($literal -match '(?m)^model = "gpt-6-sol"$') 'Literal TOML strings were not handled.'
Assert-DesktopFailure { New-NeuroAPIDesktopConfig -Original 'model = """multiline"""' @options }
$nestedMultiline = @'
[mcp_servers.demo]
url = "https://example.test/mcp"
notes = """
[features]
remote_plugin = true
"""
'@
# Both forms are valid TOML strings; their fake table must never be edited.
Assert-DesktopFailure { New-NeuroAPIDesktopConfig -Original $nestedMultiline @options }
$nestedLiteral = $nestedMultiline.Replace('"""', ("'" * 3))
Assert-DesktopFailure { New-NeuroAPIDesktopConfig -Original $nestedLiteral @options }
Assert-DesktopFailure { New-NeuroAPIDesktopConfig -Original "model = `"one`"`nmodel = `"two`"" @options }
foreach ($shape in @('[features]', "['features']`nplugins = true", "[`"features`"]`n`"remote_plugin`" = true")) {
    $configured = New-NeuroAPIDesktopConfig -Original $shape @options
    Assert-Desktop ($configured -match '(?m)^remote_plugin = false$') 'Empty or quoted features table was not updated.'
}
foreach ($shape in @(
    "[features]`nremote_plugin = true`nremote_plugin = false",
    "[features]`nremote_plugin = 'true'",
    "[features]`n[features]",
    'features = { plugins = true }',
    'features.plugins = true'
)) {
    Assert-DesktopFailure { New-NeuroAPIDesktopConfig -Original $shape @options }
}
Assert-DesktopFailure { New-NeuroAPIDesktopConfig -Original '' -HelperPath $options.HelperPath -SecretPath $options.SecretPath -CatalogPath $options.CatalogPath -DefaultModel 'bad model' }

$temp = Join-Path ([IO.Path]::GetTempPath()) ('neuroapi-desktop-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    $statePath = Join-Path $temp 'codex-desktop-state.json'
    [IO.File]::WriteAllText($statePath, ('{"version":1,"provider":"neuroapi_agents","applied_hash":"' + (Get-NeuroAPIDesktopHash -Text $fresh) + '","original_exists":false}'))
    $state = Get-NeuroAPIDesktopState -ConfigRoot $temp
    Assert-Desktop ($state.applied_hash -ceq (Get-NeuroAPIDesktopHash -Text $fresh)) 'Owned config digest mismatch.'
    [IO.File]::WriteAllText($statePath, '{}')
    Assert-DesktopFailure { Get-NeuroAPIDesktopState -ConfigRoot $temp }
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force
}
Write-Host 'Codex Desktop config tests passed.'
