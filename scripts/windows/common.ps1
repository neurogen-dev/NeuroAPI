Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:OwnerMarkerText = 'neuroapi-agents:v1'
$script:ProfileFileName = 'neuroapi-host.config.toml'
$script:ProfileMarkerFileName = '.neuroapi-host.config.toml.neuroapi-agents-owned'

function Get-DefaultStateRoot {
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        throw 'LOCALAPPDATA is not available.'
    }
    return [System.IO.Path]::Combine($env:LOCALAPPDATA, 'NeuroAPIAgents')
}

function Get-DefaultCodexHome {
    if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        throw 'USERPROFILE is not available.'
    }
    return [System.IO.Path]::Combine($env:USERPROFILE, '.codex')
}

function Get-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content
    )
    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-StateMarkerPath {
    param([Parameter(Mandatory = $true)][string]$StateRoot)
    return [System.IO.Path]::Combine($StateRoot, '.neuroapi-agents-owned')
}

function Get-ProfileMarkerPath {
    param([Parameter(Mandatory = $true)][string]$CodexHome)
    return [System.IO.Path]::Combine($CodexHome, $script:ProfileMarkerFileName)
}

function Test-OwnerMarker {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }
    return ((Get-Content -LiteralPath $Path -Raw).Trim() -eq $script:OwnerMarkerText)
}

function Write-OwnerMarker {
    param([Parameter(Mandatory = $true)][string]$Path)
    Write-Utf8NoBom -Path $Path -Content $script:OwnerMarkerText
}

function Assert-StateRootIsOwnedOrEmpty {
    param([Parameter(Mandatory = $true)][string]$StateRoot)
    if (-not (Test-Path -LiteralPath $StateRoot -PathType Container)) {
        return
    }

    $marker = Get-StateMarkerPath -StateRoot $StateRoot
    if (Test-OwnerMarker -Path $marker) {
        return
    }

    $firstItem = Get-ChildItem -LiteralPath $StateRoot -Force | Select-Object -First 1
    if ($null -ne $firstItem) {
        throw "Refusing to modify unowned directory: $StateRoot"
    }
}

function ConvertTo-TomlBasicString {
    param([Parameter(Mandatory = $true)][string]$Value)
    $escaped = $Value.Replace('\', '\\').Replace('"', '\"')
    return '"' + $escaped + '"'
}

function Add-UserPathEntry {
    param([Parameter(Mandatory = $true)][string]$Entry)
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @()
    if (-not [string]::IsNullOrWhiteSpace($current)) {
        $parts = @($current -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    $alreadyPresent = $false
    foreach ($part in $parts) {
        if ([string]::Equals(
            (Get-FullPath -Path $part.TrimEnd('\')),
            (Get-FullPath -Path $Entry.TrimEnd('\')),
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            $alreadyPresent = $true
            break
        }
    }

    if (-not $alreadyPresent) {
        $parts += $Entry
        [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
    }
}

function Remove-UserPathEntry {
    param([Parameter(Mandatory = $true)][string]$Entry)
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ([string]::IsNullOrWhiteSpace($current)) {
        return
    }

    $target = Get-FullPath -Path $Entry.TrimEnd('\')
    $kept = foreach ($part in ($current -split ';')) {
        if ([string]::IsNullOrWhiteSpace($part)) {
            continue
        }
        $candidate = Get-FullPath -Path $part.TrimEnd('\')
        if (-not [string]::Equals(
            $candidate,
            $target,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            $part
        }
    }
    [Environment]::SetEnvironmentVariable('Path', (@($kept) -join ';'), 'User')
}
