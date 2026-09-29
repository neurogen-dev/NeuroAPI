Set-StrictMode -Version Latest

$script:DesktopProviderId = 'neuroapi_agents'
$script:DesktopMetadataName = 'codex-desktop-state.json'
$script:DesktopOriginalName = 'codex-desktop-original.toml'
$script:DesktopCatalogName = 'codex-desktop-models.json'

function Get-NeuroAPIDesktopHash {
    param([AllowEmptyString()][string]$Text)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Assert-NeuroAPIDesktopFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'Codex Desktop configuration contains a directory or link. No changes were made.'
    }
}

function Get-NeuroAPIDesktopState {
    param([string]$ConfigRoot)
    $metadata = Join-Path $ConfigRoot $script:DesktopMetadataName
    Assert-NeuroAPIDesktopFile -Path $metadata
    if (-not (Test-Path -LiteralPath $metadata)) { return $null }
    try {
        $state = [IO.File]::ReadAllText($metadata) | ConvertFrom-Json -ErrorAction Stop
        if ($state.version -ne 1 -or $state.provider -cne $script:DesktopProviderId -or
            $state.applied_hash -cnotmatch '^[a-f0-9]{64}$' -or
            $state.original_exists -isnot [bool]) { throw 'Invalid ownership state' }
        if ($state.original_exists -and $state.original_hash -cnotmatch '^[a-f0-9]{64}$') {
            throw 'Invalid original hash'
        }
        return $state
    } catch {
        throw 'Codex Desktop ownership state is invalid. No changes were made.'
    }
}

function New-NeuroAPIDesktopConfig {
    param(
        [AllowEmptyString()][string]$Original,
        [string]$HelperPath,
        [string]$SecretPath,
        [string]$CatalogPath,
        [string]$DefaultModel
    )
    if (-not (Test-NeuroAPIModelId $DefaultModel)) { throw 'No valid Codex model is available for this key.' }
    if ($Original -match '(?m)^\s*\[\s*model_providers\.\s*(?:neuroapi_agents|"neuroapi_agents"|''neuroapi_agents'')(?:\.|\])') {
        throw 'The Codex provider ID is already in use. No changes were made.'
    }
    $lines = [regex]::Split($Original, '\r\n|\n|\r')
    $firstTable = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\[') { $firstTable = $i; break }
    }
    [string[]]$header = @()
    [string[]]$tail = @()
    if ($firstTable -gt 0) { $header = @($lines[0..($firstTable - 1)]) }
    if ($firstTable -lt $lines.Count) { $tail = @($lines[$firstTable..($lines.Count - 1)]) }
    if (($header -join "`n") -match '("""|'''''')') {
        throw 'Multiline root TOML cannot be edited safely. No changes were made.'
    }
    $values = [ordered]@{
        model_provider = (ConvertTo-TomlBasicString -Value $script:DesktopProviderId)
        model_catalog_json = (ConvertTo-TomlBasicString -Value $CatalogPath)
        model = (ConvertTo-TomlBasicString -Value $DefaultModel)
    }
    foreach ($key in @($values.Keys)) {
        $found = @()
        for ($i = 0; $i -lt $header.Count; $i++) {
            if ($header[$i] -match ('^\s*' + $key + '\s*=')) { $found += $i }
        }
        if ($found.Count -gt 1) { throw "Duplicate Codex setting: $key" }
        if ($found.Count -eq 1) {
            # Reject unusual/multiline assignments rather than corrupting them.
            if ($header[$found[0]] -notmatch ('^\s*' + $key + '\s*=\s*(?:"(?:[^"\\]|\\.)*"|''[^'']*'')(?<suffix>\s*(?:#.*)?)$')) {
                throw "Unsupported Codex setting syntax: $key"
            }
            $header[$found[0]] = $key + ' = ' + $values[$key] + $Matches.suffix
        } else {
            $header += ($key + ' = ' + $values[$key])
        }
    }
    $base = ((@($header) + @($tail)) -join "`n").TrimEnd("`r", "`n")
    $tomlHelper = ConvertTo-TomlBasicString -Value $HelperPath
    $tomlSecret = ConvertTo-TomlBasicString -Value $SecretPath
    return ($base + "`n`n" + @"
# BEGIN NEUROAPI CODEX DESKTOP
[model_providers.neuroapi_agents]
name = "NeuroAPI"
base_url = "https://codex.neuroapi.host/v1"
wire_api = "responses"
supports_websockets = false

[model_providers.neuroapi_agents.auth]
command = "powershell.exe"
args = ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", $tomlHelper, "-SecretPath", $tomlSecret]
timeout_ms = 5000
refresh_interval_ms = 300000
# END NEUROAPI CODEX DESKTOP
"@.TrimStart() + "`n")
}

function Assert-NeuroAPIDesktopConfigWithCodex {
    param([string]$Config, [string]$StageRoot, [string]$CodexBinary)
    if (-not (Test-Path -LiteralPath $CodexBinary -PathType Leaf)) {
        throw 'Codex CLI is required to validate the desktop configuration.'
    }
    $validationRoot = Join-Path $StageRoot 'codex-validate'
    Ensure-Directory -Path $validationRoot
    Write-Utf8NoBom -Path (Join-Path $validationRoot 'config.toml') -Content $Config
    $previous = $env:CODEX_HOME
    try {
        $env:CODEX_HOME = $validationRoot
        $output = & $CodexBinary features list 2>&1
        if ($LASTEXITCODE -ne 0) { throw 'Codex rejected the desktop configuration.' }
    } finally {
        $env:CODEX_HOME = $previous
    }
}
