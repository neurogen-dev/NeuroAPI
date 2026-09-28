Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $repoRoot 'scripts/windows/common.ps1')

$stateRoot = Join-Path ([IO.Path]::GetTempPath()) ('neuroapi-native-clients-' + [Guid]::NewGuid().ToString('N'))
try {
    Ensure-Directory -Path (Join-Path $stateRoot 'bin')
    Install-NeuroAPICodex -StateRoot $stateRoot
    $codex = Get-NeuroAPIClientExecutable -Client codex -StateRoot $stateRoot
    if ($codex -cne (Join-Path $stateRoot 'native-codex/codex.exe')) {
        throw 'The native Codex executable was not selected.'
    }
    Assert-NeuroAPIClientReady -Client codex -Command $codex

    Install-NeuroAPIClaude -StateRoot $stateRoot | Out-Host
    $claude = Get-NeuroAPIClientExecutable -Client claude -StateRoot $stateRoot
    Assert-NeuroAPIClientReady -Client claude -Command $claude
    Write-Host 'Official native Codex and Claude clients installed and launched.'
} finally {
    if (Test-Path -LiteralPath $stateRoot) {
        Remove-Item -LiteralPath $stateRoot -Recurse -Force
    }
}
