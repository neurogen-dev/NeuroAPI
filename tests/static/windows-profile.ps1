param([string]$PythonExecutable = 'python3')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $repoRoot 'scripts/windows/common.ps1')
if ((Resolve-CodexConfigRoot -ConfiguredRoot 'C:\Custom profile' -UserRoot $null) -cne 'C:\Custom profile') {
    throw 'Configured CODEX_HOME was not preserved.'
}
$expectedDefault = [System.IO.Path]::Combine('C:\User', '.codex')
if ((Resolve-CodexConfigRoot -ConfiguredRoot '' -UserRoot 'C:\User') -cne $expectedDefault) {
    throw 'Default Codex profile root was not resolved.'
}


# Render only the data template. Never execute setup, a helper or DPAPI here.
$source = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts/windows/setup.ps1') -Raw
$match = [regex]::Match($source, '(?ms)^\$profile = @"\r?\n(.*?)^"@')
if (-not $match.Success) { throw 'Windows profile template was not found.' }
$helperPath = 'C:\Test user\NeuroAPI\bin\get-neuroapi-key.ps1'
$secretPath = 'C:\Test user\NeuroAPI\secret\api-key.dpapi'
$template = $match.Groups[1].Value
$withoutKnownVariables = $template.Replace('$tomlHelperPath', '').Replace('$tomlSecretPath', '')
if ($withoutKnownVariables.Contains('$') -or $withoutKnownVariables.Contains('`')) {
    throw 'Unexpected executable interpolation in the profile template.'
}
$profile = $template.Replace('$tomlHelperPath', (ConvertTo-TomlBasicString -Value $helperPath)).Replace(
    '$tomlSecretPath', (ConvertTo-TomlBasicString -Value $secretPath)
)
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('neuroapi-profile-' + [Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    $profilePath = Join-Path $tempRoot 'neuroapi-host.config.toml'
    Write-Utf8NoBom -Path $profilePath -Content $profile
    & $PythonExecutable (Join-Path $PSScriptRoot 'profile_contract.py') $profilePath windows $helperPath $secretPath
    if ($LASTEXITCODE -ne 0) { throw 'Windows profile contract failed.' }
} finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
