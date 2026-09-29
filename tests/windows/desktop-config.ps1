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
Assert-Desktop ($fresh -match '(?m)^model = "gpt-6-sol"$') 'Fresh config has no supported default.'
Assert-Desktop ($fresh -match '(?m)^base_url = "https://codex.neuroapi.host/v1"$') 'Desktop subdomain is wrong.'
Assert-Desktop ($fresh -match '(?m)^supports_websockets = false$') 'Unproven WebSocket path was enabled.'
Assert-Desktop ($fresh -notmatch 'sk-|experimental_bearer_token') 'A token was embedded in desktop config.'
Assert-Desktop ($fresh -match '# BEGIN NEUROAPI CODEX DESKTOP' -and $fresh -match '# END NEUROAPI CODEX DESKTOP') 'Ownership markers missing.'

$existing = @'
# User comment
model = "old-model" # keep elsewhere
model_provider = "other"
[features]
multi_agent = true
[mcp_servers.demo]
url = "https://example.test/mcp"
'@
$updated = New-NeuroAPIDesktopConfig -Original $existing @options
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
Assert-DesktopFailure { New-NeuroAPIDesktopConfig -Original "model = `"one`"`nmodel = `"two`"" @options }
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
