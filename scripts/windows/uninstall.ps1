[CmdletBinding()]
param(
    [switch]$TestMode,
    [string]$StateRoot,
    [string]$CodexHome,
    [switch]$NoPathUpdate
)

. "$PSScriptRoot\common.ps1"

if ($env:OS -ne 'Windows_NT') {
    throw 'This uninstaller must run on Windows.'
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

if (-not $TestMode) {
    if (-not [string]::Equals($StateRoot, $defaultStateRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'A custom StateRoot is allowed only in test mode.'
    }
    if (-not [string]::Equals($CodexHome, $defaultCodexHome, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'A custom CodexHome is allowed only in test mode.'
    }
    $confirmation = Read-Host 'Delete the NeuroAPI launchers and the locally protected API key? Type DELETE'
    if ($confirmation -cne 'DELETE') {
        Write-Host 'Uninstall cancelled. Nothing was removed.'
        return
    }
}

$stateMarkerPath = Get-StateMarkerPath -StateRoot $StateRoot
if ((Test-Path -LiteralPath $StateRoot -PathType Container) -and
    -not (Test-OwnerMarker -Path $stateMarkerPath)) {
    throw "Refusing to remove an unowned directory: $StateRoot"
}

$profilePath = [System.IO.Path]::Combine($CodexHome, $script:ProfileFileName)
$profileMarkerPath = Get-ProfileMarkerPath -CodexHome $CodexHome
if (Test-Path -LiteralPath $profilePath -PathType Leaf) {
    if (-not (Test-OwnerMarker -Path $profileMarkerPath)) {
        Write-Warning "Leaving unowned Codex profile in place: $profilePath"
    } else {
        Remove-Item -LiteralPath $profilePath -Force
        Remove-Item -LiteralPath $profileMarkerPath -Force
    }
} elseif (Test-Path -LiteralPath $profileMarkerPath -PathType Leaf) {
    Remove-Item -LiteralPath $profileMarkerPath -Force
}

$binRoot = [System.IO.Path]::Combine($StateRoot, 'bin')
if (-not $TestMode -and -not $NoPathUpdate) {
    Remove-UserPathEntry -Entry $binRoot
}

if (Test-Path -LiteralPath $StateRoot -PathType Container) {
    Remove-Item -LiteralPath $StateRoot -Recurse -Force
}

Write-Host 'Removed NeuroAPI installer-owned files and the protected local API key.'
Write-Host 'The deleted key cannot be recovered from this installer.'
