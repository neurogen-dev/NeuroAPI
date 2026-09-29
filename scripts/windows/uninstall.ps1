[CmdletBinding()]
param(
    [switch]$TestMode,
    [string]$StateRoot,
    [string]$CodexHome,
    [switch]$NoPathUpdate
)

. "$PSScriptRoot\common.ps1"
. "$PSScriptRoot\desktop-config.ps1"

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

if ($TestMode -and (
    [string]::Equals($StateRoot, $defaultStateRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    [string]::Equals($CodexHome, $defaultCodexHome, [System.StringComparison]::OrdinalIgnoreCase)
)) {
    throw 'Test mode requires isolated StateRoot and CodexHome paths.'
}
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

$configRoot = Join-Path $StateRoot 'config'
$desktopState = Get-NeuroAPIDesktopState -ConfigRoot $configRoot
$desktopConfigPath = Join-Path $CodexHome 'config.toml'
$desktopOriginalPath = Join-Path $configRoot $script:DesktopOriginalName
Assert-NeuroAPIDesktopFile -Path $desktopConfigPath
if ($null -ne $desktopState) {
    Assert-NeuroAPIDesktopFile -Path $desktopOriginalPath
    if (-not (Test-Path -LiteralPath $desktopConfigPath -PathType Leaf) -or
        (Get-FileHash -LiteralPath $desktopConfigPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $desktopState.applied_hash) {
        throw 'Codex Desktop config.toml changed after setup. Uninstall stopped; the protected key and helper remain available. Restore the config manually, then retry.'
    }
    if ($desktopState.original_exists -and -not (Test-Path -LiteralPath $desktopOriginalPath -PathType Leaf)) {
        throw 'Codex Desktop backup is missing. Uninstall stopped; the protected key remains available.'
    }
    if ($desktopState.original_exists -and
        (Get-FileHash -LiteralPath $desktopOriginalPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $desktopState.original_hash) {
        throw 'Codex Desktop backup changed. Uninstall stopped; the protected key remains available.'
    }
    if (-not $desktopState.original_exists -and (Test-Path -LiteralPath $desktopOriginalPath)) {
        throw 'Codex Desktop backup state is inconsistent. Uninstall stopped.'
    }
} elseif (Test-Path -LiteralPath $desktopConfigPath -PathType Leaf) {
    $current = [IO.File]::ReadAllText($desktopConfigPath)
    if ($current.Contains('[model_providers.neuroapi_agents]')) {
        throw 'Codex Desktop still uses the NeuroAPI provider, but installer ownership metadata is missing. Uninstall stopped to preserve its credential helper.'
    }
}

if ($null -ne $desktopState) {
    # The complete hash check deliberately refuses to overwrite later user edits.
    # Keep credentials until the desktop configuration has been restored.
    if ($desktopState.original_exists) {
        $temporary = $desktopConfigPath + '.neuroapi-restore-' + [Guid]::NewGuid().ToString('N')
        $discard = $desktopConfigPath + '.neuroapi-discard-' + [Guid]::NewGuid().ToString('N')
        try {
            Copy-Item -LiteralPath $desktopOriginalPath -Destination $temporary -ErrorAction Stop
            [IO.File]::Replace($temporary, $desktopConfigPath, $discard)
        } finally {
            if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
            if (Test-Path -LiteralPath $discard) { Remove-Item -LiteralPath $discard -Force }
        }
    } else {
        [IO.File]::Delete($desktopConfigPath)
    }
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
    Remove-OwnedUserPathEntries -StateRoot $StateRoot
}

if (Test-Path -LiteralPath $StateRoot -PathType Container) {
    Remove-Item -LiteralPath $StateRoot -Recurse -Force
}

Write-Host 'Removed NeuroAPI installer-owned files and the protected local API key.'
Write-Host 'The deleted key cannot be recovered from this installer.'
